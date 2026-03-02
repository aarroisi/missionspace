defmodule Bridge.Lists do
  @moduledoc """
  The Lists context.
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo

  alias Bridge.Lists.{List, ListStatus, Task}
  alias Bridge.Chat.Message

  @default_statuses [
    %{name: "TODO", color: "#6b7280", position: 0, is_done: false},
    %{name: "DOING", color: "#3b82f6", position: 1, is_done: false},
    %{name: "DONE", color: "#22c55e", position: 2, is_done: true}
  ]

  # ============================================================================
  # List functions
  # ============================================================================

  def list_lists(workspace_id, user, opts \\ []) do
    List
    |> where([l], l.workspace_id == ^workspace_id)
    |> filter_accessible_lists(user)
    |> order_by([l], desc: l.id)
    |> preload([:created_by, :statuses])
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  def list_starred_lists(workspace_id, user, opts \\ []) do
    starred_ids = Bridge.Stars.starred_ids(user.id, "board")

    if MapSet.size(starred_ids) == 0 do
      %{entries: [], metadata: %{after: nil, before: nil, limit: 50}}
    else
      ids = MapSet.to_list(starred_ids)

      List
      |> where([l], l.id in ^ids and l.workspace_id == ^workspace_id)
      |> filter_accessible_lists(user)
      |> order_by([l], desc: l.id)
      |> preload([:created_by, :statuses])
      |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
    end
  end

  defp filter_accessible_lists(query, %{role: "owner", id: user_id}) do
    # Owner sees: all shared items + own private items
    where(query, [l], l.visibility == "shared" or l.created_by_id == ^user_id)
  end

  defp filter_accessible_lists(query, %{id: user_id}) do
    # Non-owner sees: project items + own items + invited shared items
    project_list_ids = Bridge.Projects.get_project_item_ids_for_user_projects(user_id, "list")
    item_member_ids = Bridge.Projects.get_user_item_member_ids(user_id, "list")

    where(
      query,
      [l],
      l.id in ^project_list_ids or
        l.created_by_id == ^user_id or
        (l.visibility == "shared" and l.id in ^item_member_ids)
    )
  end

  def get_list(id, workspace_id) do
    case List
         |> where([l], l.workspace_id == ^workspace_id)
         |> preload([
           :created_by,
           statuses: [],
           tasks: [:assignee, :created_by, :status]
         ])
         |> Repo.get(id) do
      nil ->
        {:error, :not_found}

      list ->
        # Filter to only top-level tasks and add counts
        top_level_tasks =
          list.tasks
          |> Enum.filter(&is_nil(&1.parent_id))
          |> add_comment_counts_to_tasks()
          |> add_child_counts_to_tasks()

        {:ok, %{list | tasks: top_level_tasks}}
    end
  end

  defp add_comment_counts_to_tasks(tasks) when is_list(tasks) do
    task_ids = Enum.map(tasks, & &1.id)

    counts =
      from(m in Message,
        where: m.entity_type == "task" and m.entity_id in ^task_ids,
        group_by: m.entity_id,
        select: {m.entity_id, count(m.id)}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(tasks, fn task ->
      %{task | comment_count: Map.get(counts, task.id, 0)}
    end)
  end

  defp add_comment_counts_to_tasks(tasks), do: tasks

  defp add_child_counts_to_tasks(tasks) when is_list(tasks) do
    task_ids = Enum.map(tasks, & &1.id)

    counts =
      from(t in Task,
        where: t.parent_id in ^task_ids,
        group_by: t.parent_id,
        select: {t.parent_id, count(t.id), sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", t.is_completed))}
      )
      |> Repo.all()
      |> Map.new(fn {parent_id, total, done} -> {parent_id, {total, done}} end)

    Enum.map(tasks, fn task ->
      {total, done} = Map.get(counts, task.id, {0, 0})
      %{task | child_count: total, child_done_count: done}
    end)
  end

  defp add_child_counts_to_tasks(tasks), do: tasks

  def create_list(attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, list} <-
             %List{}
             |> List.create_changeset(attrs)
             |> Repo.insert(),
           {:ok, _prefix} <-
             Bridge.Namespaces.reserve_prefix(
               list.prefix,
               "list",
               list.id,
               list.workspace_id
             ) do
        Enum.each(@default_statuses, fn status_attrs ->
          %ListStatus{}
          |> ListStatus.changeset(Map.put(status_attrs, :list_id, list.id))
          |> Repo.insert!()
        end)

        list |> Repo.preload(:statuses)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update_list(%List{} = list, attrs) do
    list
    |> List.changeset(attrs)
    |> Repo.update()
  end

  def delete_list(%List{} = list) do
    result = Repo.delete(list)

    case result do
      {:ok, _} -> Bridge.Namespaces.release_prefix("list", list.id)
      _ -> nil
    end

    result
  end

  def change_list(%List{} = list, attrs \\ %{}) do
    List.changeset(list, attrs)
  end


  defdelegate suggest_prefix(name, workspace_id), to: Bridge.Namespaces
  defdelegate check_prefix_available?(prefix, workspace_id), to: Bridge.Namespaces

  # ============================================================================
  # List Status functions
  # ============================================================================

  def list_statuses(list_id) do
    ListStatus
    |> where([s], s.list_id == ^list_id)
    |> order_by([s], asc: s.position)
    |> Repo.all()
  end

  def get_status(id) do
    case Repo.get(ListStatus, id) do
      nil -> {:error, :not_found}
      status -> {:ok, status}
    end
  end

  def create_status(attrs \\ %{}) do
    list_id = attrs["list_id"] || attrs[:list_id]

    done_status =
      ListStatus
      |> where([s], s.list_id == ^list_id and s.is_done == true)
      |> Repo.one()

    Repo.transaction(fn ->
      new_position =
        if done_status do
          ListStatus
          |> where([s], s.id == ^done_status.id)
          |> Repo.update_all(inc: [position: 1])

          done_status.position
        else
          max_position =
            ListStatus
            |> where([s], s.list_id == ^list_id)
            |> select([s], max(s.position))
            |> Repo.one() || -1

          max_position + 1
        end

      attrs_with_position = Map.put(attrs, "position", new_position)

      case %ListStatus{}
           |> ListStatus.changeset(attrs_with_position)
           |> Repo.insert() do
        {:ok, status} -> status
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update_status(%ListStatus{} = status, attrs) do
    status
    |> ListStatus.changeset(attrs)
    |> Repo.update()
  end

  def delete_status(%ListStatus{} = status) do
    if status.is_done do
      {:error, :is_done_status}
    else
      task_count =
        Task
        |> where([t], t.status_id == ^status.id)
        |> Repo.aggregate(:count, :id)

      if task_count > 0 do
        {:error, :has_tasks}
      else
        Repo.delete(status)
      end
    end
  end

  def reorder_statuses(list_id, status_ids) when is_list(status_ids) do
    statuses =
      ListStatus
      |> where([s], s.list_id == ^list_id)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    done_status = Enum.find(statuses, fn {_id, s} -> s.is_done end)

    case done_status do
      {done_id, _} ->
        last_id = Elixir.List.last(status_ids)

        if last_id != done_id do
          {:error, :done_must_be_last}
        else
          do_reorder_statuses(list_id, status_ids)
        end

      nil ->
        do_reorder_statuses(list_id, status_ids)
    end
  end

  defp do_reorder_statuses(list_id, status_ids) do
    Repo.transaction(fn ->
      status_ids
      |> Enum.with_index()
      |> Enum.each(fn {status_id, index} ->
        ListStatus
        |> where([s], s.id == ^status_id and s.list_id == ^list_id)
        |> Repo.update_all(set: [position: index])
      end)

      list_statuses(list_id)
    end)
  end

  # ============================================================================
  # Task functions
  # ============================================================================

  @doc """
  Returns top-level tasks (no parent) for a board.
  """
  def list_tasks(list_id, opts \\ []) when is_binary(list_id) do
    page =
      Task
      |> where([t], t.list_id == ^list_id and is_nil(t.parent_id))
      |> order_by([t], asc: t.position, desc: t.id)
      |> preload([:list, :assignee, :created_by, :status])
      |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))

    tasks_with_counts =
      page.entries
      |> add_comment_counts_to_tasks()
      |> add_child_counts_to_tasks()

    %{page | entries: tasks_with_counts}
  end

  @doc """
  Returns top-level tasks assigned to a user.
  """
  def list_tasks_by_assignee(assignee_id, workspace_id) do
    Task
    |> join(:inner, [t], l in assoc(t, :list))
    |> where([t, l], t.assignee_id == ^assignee_id and l.workspace_id == ^workspace_id and is_nil(t.parent_id) and is_nil(t.completed_at))
    |> order_by([t], desc: t.inserted_at)
    |> preload([:list, :assignee, :created_by, :status])
    |> Repo.all()
  end

  @doc """
  Returns child tasks (subtasks) assigned to a user.
  """
  def list_child_tasks_by_assignee(assignee_id, workspace_id) do
    Task
    |> join(:inner, [t], l in assoc(t, :list))
    |> where([t, l], t.assignee_id == ^assignee_id and l.workspace_id == ^workspace_id and not is_nil(t.parent_id) and is_nil(t.completed_at))
    |> order_by([t], desc: t.inserted_at)
    |> preload([:list, :assignee, :created_by, :status, :parent])
    |> Repo.all()
  end

  @doc """
  Returns all starred tasks (both parent and child) in a workspace.
  """
  def list_starred_tasks(workspace_id, user_id) do
    starred_ids = Bridge.Stars.starred_ids(user_id, "task")

    if MapSet.size(starred_ids) == 0 do
      []
    else
      ids = MapSet.to_list(starred_ids)

      Task
      |> join(:inner, [t], l in assoc(t, :list))
      |> where([t, l], t.id in ^ids and l.workspace_id == ^workspace_id)
      |> order_by([t], desc: t.inserted_at)
      |> preload([:list, :assignee, :created_by, :status, :parent])
      |> Repo.all()
      |> Enum.map(fn task -> %{task | starred: true} end)
    end
  end

  def list_tasks_by_status_id(status_id) do
    Task
    |> where([t], t.status_id == ^status_id)
    |> preload([:list, :assignee, :created_by, :status])
    |> Repo.all()
  end

  def list_tasks_due_by(date) do
    Task
    |> where([t], not is_nil(t.due_on) and t.due_on <= ^date)
    |> preload([:list, :assignee, :created_by])
    |> order_by([t], asc: t.due_on)
    |> Repo.all()
  end

  @doc """
  Returns child tasks for a parent task.
  """
  def list_child_tasks(parent_id) do
    Task
    |> where([t], t.parent_id == ^parent_id)
    |> order_by([t], asc: t.inserted_at)
    |> preload([:list, :assignee, :created_by, :status, :parent])
    |> Repo.all()
  end

  def get_task(id) do
    case Task
         |> preload(
           list: [:statuses],
           status: [],
           parent: [],
           assignee: [],
           created_by: []
         )
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  def create_task(attrs \\ %{}) do
    parent_id = attrs["parent_id"] || attrs[:parent_id]

    with :ok <- validate_single_level_nesting(parent_id) do
      do_create_task(attrs, parent_id)
    end
  end

  defp validate_single_level_nesting(nil), do: :ok

  defp validate_single_level_nesting(parent_id) do
    case Repo.get(Task, parent_id) do
      %Task{parent_id: nil} ->
        :ok

      %Task{} ->
        changeset =
          %Task{}
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.add_error(:parent_id, "cannot create subtask of a subtask")

        {:error, changeset}

      nil ->
        {:error, :not_found}
    end
  end

  defp do_create_task(attrs, parent_id) do
    list_id = attrs["list_id"] || attrs[:list_id]
    status_id = attrs["status_id"] || attrs[:status_id]

    # For child tasks, inherit list_id from parent if not provided
    list_id =
      if parent_id && !list_id do
        Task
        |> where([t], t.id == ^parent_id)
        |> select([t], t.list_id)
        |> Repo.one()
      else
        list_id
      end

    attrs = Map.put(attrs, "list_id", list_id)

    # Default to first status if not specified
    status_id =
      cond do
        status_id -> status_id
        true -> get_first_status_id(list_id)
      end

    # Child tasks don't need position calculation
    max_position =
      if parent_id do
        0
      else
        get_max_position_by_status_id(list_id, status_id)
      end

    # Atomically increment the board's sequence counter
    seq_num =
      if is_binary(list_id) do
        {1, [%{task_sequence_counter: counter}]} =
          from(l in List,
            where: l.id == ^list_id,
            select: %{task_sequence_counter: l.task_sequence_counter}
          )
          |> Repo.update_all(inc: [task_sequence_counter: 1])

        counter
      else
        0
      end

    position = if parent_id, do: 0, else: max_position + 1000

    attrs_with_defaults =
      attrs
      |> Map.put("position", position)
      |> Map.put("status_id", status_id)
      |> Map.put("sequence_number", seq_num)

    result =
      %Task{}
      |> Task.changeset(attrs_with_defaults)
      |> Repo.insert()

    case result do
      {:ok, task} -> {:ok, Repo.preload(task, [:list, :status, :assignee, :created_by])}
      error -> error
    end
  end

  defp get_first_status_id(list_id) when is_binary(list_id) do
    ListStatus
    |> where([s], s.list_id == ^list_id)
    |> order_by([s], asc: s.position)
    |> limit(1)
    |> select([s], s.id)
    |> Repo.one()
  end

  defp get_first_status_id(_), do: nil

  defp get_done_status_id(list_id) when is_binary(list_id) do
    ListStatus
    |> where([s], s.list_id == ^list_id and s.is_done == true)
    |> limit(1)
    |> select([s], s.id)
    |> Repo.one()
  end

  defp get_done_status_id(_), do: nil

  defp get_max_position_by_status_id(list_id, status_id)
       when is_binary(list_id) and is_binary(status_id) do
    Task
    |> where([t], t.list_id == ^list_id and t.status_id == ^status_id)
    |> select([t], max(t.position))
    |> Repo.one() || 0
  end

  defp get_max_position_by_status_id(_, _), do: 0

  def create_task(list_id, attrs) when is_binary(list_id) do
    attrs
    |> Map.put(:list_id, list_id)
    |> create_task()
  end

  def update_task(%Task{} = task, attrs) do
    attrs = maybe_update_task_completed_at(task, attrs)
    attrs = maybe_update_child_task_completed_at(task, attrs)

    case task
         |> Task.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_task} ->
        {:ok, Repo.preload(updated_task, [:list, :status, :assignee, :created_by], force: true)}

      error ->
        error
    end
  end

  # For top-level tasks: check if status is changing to done/undone
  defp maybe_update_task_completed_at(%Task{parent_id: nil} = task, attrs) do
    new_status_id = attrs[:status_id] || attrs["status_id"]

    use_string_keys = Map.has_key?(attrs, "status_id") || Map.has_key?(attrs, "title")
    completed_at_key = if use_string_keys, do: "completed_at", else: :completed_at

    cond do
      is_nil(new_status_id) ->
        attrs

      new_status_id != task.status_id ->
        new_status = Repo.get(ListStatus, new_status_id)

        cond do
          new_status && new_status.is_done && is_nil(task.completed_at) ->
            Map.put(attrs, completed_at_key, DateTime.utc_now())

          new_status && !new_status.is_done && !is_nil(task.completed_at) ->
            Map.put(attrs, completed_at_key, nil)

          true ->
            attrs
        end

      true ->
        attrs
    end
  end

  defp maybe_update_task_completed_at(_task, attrs), do: attrs

  # For child tasks: check if is_completed is changing and sync status_id
  defp maybe_update_child_task_completed_at(%Task{parent_id: parent_id} = task, attrs)
       when not is_nil(parent_id) do
    new_is_completed = attrs[:is_completed] || attrs["is_completed"]

    use_string_keys = Map.has_key?(attrs, "is_completed") || Map.has_key?(attrs, "title")
    completed_at_key = if use_string_keys, do: "completed_at", else: :completed_at
    status_id_key = if use_string_keys, do: "status_id", else: :status_id

    cond do
      is_nil(new_is_completed) ->
        attrs

      new_is_completed == true && task.is_completed != true ->
        attrs = Map.put(attrs, completed_at_key, DateTime.utc_now())
        done_status_id = get_done_status_id(task.list_id)
        if done_status_id, do: Map.put(attrs, status_id_key, done_status_id), else: attrs

      new_is_completed == false && task.is_completed == true ->
        attrs = Map.put(attrs, completed_at_key, nil)
        first_status_id = get_first_status_id(task.list_id)
        if first_status_id, do: Map.put(attrs, status_id_key, first_status_id), else: attrs

      true ->
        attrs
    end
  end

  defp maybe_update_child_task_completed_at(_task, attrs), do: attrs

  def reorder_task(%Task{} = task, target_index, new_status_id \\ nil) do
    new_status_id = new_status_id || task.status_id

    calculated_position = calculate_position(task.list_id, new_status_id, target_index, task.id)

    attrs = %{position: calculated_position, status_id: new_status_id}
    attrs = maybe_update_task_completed_at(task, attrs)

    result =
      task
      |> Task.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, task} -> {:ok, Repo.preload(task, [:list, :status, :assignee, :created_by])}
      error -> error
    end
  end

  defp calculate_position(list_id, status_id, target_index, exclude_task_id) do
    positions =
      Task
      |> where(
        [t],
        t.list_id == ^list_id and t.status_id == ^status_id and t.id != ^exclude_task_id
      )
      |> order_by([t], asc: t.position)
      |> select([t], t.position)
      |> Repo.all()

    cond do
      positions == [] or target_index == 0 ->
        case positions do
          [] -> 1000
          [first | _] -> div(first, 2)
        end

      target_index >= length(positions) ->
        Elixir.List.last(positions) + 1000

      true ->
        prev_pos = Enum.at(positions, target_index - 1)
        next_pos = Enum.at(positions, target_index)
        div(prev_pos + next_pos, 2)
    end
  end

  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  def assign_task(%Task{} = task, assignee_id) do
    update_task(task, %{assignee_id: assignee_id})
  end

  def update_task_status(%Task{} = task, status_id) do
    update_task(task, %{status_id: status_id})
  end
end
