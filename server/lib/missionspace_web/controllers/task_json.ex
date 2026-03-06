defmodule MissionspaceWeb.TaskJSON do
  alias Missionspace.Lists.Task

  def index(%{page: page}) do
    %{
      data: for(task <- page.entries, do: data(task)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def index(%{tasks: tasks}) do
    %{data: for(task <- tasks, do: data(task))}
  end

  def show(%{task: task}) do
    %{data: data(task)}
  end

  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%Task{} = task) do
    base = %{
      id: task.id,
      title: task.title,
      sequence_number: task.sequence_number,
      key: get_task_key(task),
      position: task.position,
      is_completed: task.is_completed,
      starred: task.starred,
      notes: task.notes,
      due_on: task.due_on,
      completed_at: task.completed_at,
      board_id: task.list_id,
      parent_id: task.parent_id,
      status_id: task.status_id,
      assignee_id: task.assignee_id,
      assignee: get_assignee(task),
      created_by_id: task.created_by_id,
      created_by: get_created_by(task),
      child_count: task.child_count || 0,
      child_done_count: task.child_done_count || 0,
      comment_count: task.comment_count || 0,
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }

    base = maybe_add_status(base, task)
    maybe_add_parent(base, task)
  end

  defp maybe_add_status(base, task) do
    if Ecto.assoc_loaded?(task.status) and task.status do
      Map.put(base, :status, %{
        id: task.status.id,
        name: task.status.name,
        color: task.status.color,
        position: task.status.position,
        is_done: task.status.is_done
      })
    else
      base
    end
  end

  defp maybe_add_parent(base, task) do
    if task.parent_id && Ecto.assoc_loaded?(task.parent) && task.parent do
      Map.put(base, :parent, %{
        id: task.parent.id,
        title: task.parent.title,
        board_id: task.parent.list_id
      })
    else
      base
    end
  end

  defp get_assignee(%Task{assignee: %{id: id, name: name, email: email, avatar: avatar}}),
    do: %{id: id, name: name, email: email, avatar: avatar}

  defp get_assignee(_), do: nil

  defp get_created_by(%Task{created_by: %{id: id, name: name, email: email, avatar: avatar}}),
    do: %{id: id, name: name, email: email, avatar: avatar}

  defp get_created_by(_), do: nil

  defp get_task_key(%Task{list: %Missionspace.Lists.List{prefix: prefix}, sequence_number: seq})
       when is_binary(prefix) and is_integer(seq) do
    "#{prefix}-#{seq}"
  end

  defp get_task_key(_), do: nil

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
