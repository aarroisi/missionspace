defmodule MissionspaceWeb.TaskController do
  use MissionspaceWeb, :controller

  alias Missionspace.Lists
  alias Missionspace.Projects
  alias Missionspace.Accounts
  alias Missionspace.Mentions
  alias Missionspace.Notifications
  alias Missionspace.Repo
  alias Missionspace.Subscriptions
  alias Missionspace.Authorization.Policy
  import Plug.Conn

  action_fallback(MissionspaceWeb.FallbackController)

  plug(:load_resource when action in [:show, :update, :delete, :reorder])
  plug(:authorize, :view_item when action in [:show])
  plug(:authorize, :create_item when action in [:create])
  plug(:authorize, :update_item when action in [:update, :reorder])
  plug(:authorize, :delete_item when action in [:delete])

  defp load_resource(conn, _opts) do
    case Lists.get_task(conn.params["id"]) do
      {:ok, task} ->
        assign(conn, :task, task)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  defp authorize(conn, permission) do
    user = conn.assigns.current_user
    resource = get_authorization_resource(conn, permission)

    if Policy.can?(user, permission, resource) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Forbidden"})
      |> halt()
    end
  end

  defp get_authorization_resource(conn, :create_item) do
    # For create, we need to get the board's project_id via project_items
    # Accept both board_id and list_id for backwards compatibility
    board_id = conn.params["board_id"] || conn.params["list_id"]

    if board_id do
      Projects.get_item_project_id("board", board_id)
    else
      nil
    end
  end

  defp get_authorization_resource(conn, _permission) do
    conn.assigns[:task]
  end

  def index(conn, %{"starred" => "true"}) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user
    tasks = Lists.list_starred_tasks(workspace_id, user.id)
    render(conn, :index, tasks: tasks)
  end

  def index(conn, %{"assigned_to_me" => "true", "is_subtask" => "true"}) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id
    tasks = Lists.list_child_tasks_by_assignee(current_user.id, workspace_id)
    tasks = Missionspace.Stars.mark_starred(tasks, current_user.id, "task")
    render(conn, :index, tasks: tasks)
  end

  def index(conn, %{"assigned_to_me" => "true"}) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id
    tasks = Lists.list_tasks_by_assignee(current_user.id, workspace_id)
    tasks = Missionspace.Stars.mark_starred(tasks, current_user.id, "task")
    render(conn, :index, tasks: tasks)
  end

  def index(conn, %{"parent_id" => parent_id}) when is_binary(parent_id) do
    user = conn.assigns.current_user
    tasks = Lists.list_child_tasks(parent_id)
    tasks = Missionspace.Stars.mark_starred(tasks, user.id, "task")
    render(conn, :index, tasks: tasks)
  end

  def index(conn, params) do
    board_id = params["board_id"] || params["list_id"]
    user = conn.assigns.current_user

    case board_id do
      id when is_binary(id) ->
        opts = MissionspaceWeb.PaginationHelpers.build_pagination_opts(params)
        page = Lists.list_tasks(id, opts)
        entries = Missionspace.Stars.mark_starred(page.entries, user.id, "task")
        render(conn, :index, page: %{page | entries: entries})

      _ ->
        render(conn, :index, tasks: [])
    end
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id

    # Accept both boardId and listId, convert to list_id for internal use
    task_params =
      params
      |> Map.put("created_by_id", current_user.id)
      |> normalize_board_id()
      |> normalize_parent_id()

    with {:ok, task} <- Lists.create_task(task_params) do
      # Auto-subscribe creator to the task
      Missionspace.Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task.id,
        user_id: current_user.id,
        workspace_id: workspace_id
      })

      conn
      |> put_status(:created)
      |> render(:show, task: task)
    end
  end

  # Convert boardId to list_id for internal use
  defp normalize_board_id(params) do
    cond do
      Map.has_key?(params, "boardId") ->
        params
        |> Map.put("list_id", params["boardId"])
        |> Map.delete("boardId")

      Map.has_key?(params, "board_id") ->
        params
        |> Map.put("list_id", params["board_id"])
        |> Map.delete("board_id")

      true ->
        params
    end
  end

  defp normalize_parent_id(params) do
    cond do
      Map.has_key?(params, "parentId") ->
        params
        |> Map.put("parent_id", params["parentId"])
        |> Map.delete("parentId")

      true ->
        params
    end
  end

  def show(conn, _params) do
    user = conn.assigns.current_user
    task = Missionspace.Stars.mark_starred(conn.assigns.task, user.id, "task")
    render(conn, :show, task: task)
  end

  def update(conn, params) do
    old_task = conn.assigns.task
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id
    task_params = Map.drop(params, ["id"])

    with {:ok, updated_task} <- Lists.update_task(old_task, task_params) do
      maybe_notify_notes_mentions(
        old_task,
        updated_task,
        task_params,
        current_user.id,
        workspace_id
      )

      render(conn, :show, task: updated_task)
    end
  end

  defp maybe_notify_notes_mentions(old_task, updated_task, task_params, actor_id, workspace_id) do
    notes_updated? = Map.has_key?(task_params, "notes") || Map.has_key?(task_params, :notes)

    if notes_updated? do
      old_mentions = Mentions.extract_mention_ids(old_task.notes || "") |> MapSet.new()
      new_mentions = Mentions.extract_mention_ids(updated_task.notes || "") |> MapSet.new()

      added_mentions =
        MapSet.difference(new_mentions, old_mentions)
        |> MapSet.delete(actor_id)
        |> MapSet.to_list()

      Enum.each(added_mentions, fn user_id ->
        notify_task_mention(user_id, updated_task, actor_id, workspace_id)
      end)
    end
  end

  defp notify_task_mention(user_id, task, actor_id, workspace_id) do
    with {:ok, _uuid} <- Ecto.UUID.cast(user_id),
         {:ok, mentioned_user} <- Accounts.get_workspace_user(user_id, workspace_id),
         true <- mentioned_user.is_active do
      _ =
        Subscriptions.subscribe(%{
          item_type: "task",
          item_id: task.id,
          user_id: user_id,
          workspace_id: workspace_id
        })

      case Notifications.create_notification(%{
             type: "mention",
             item_type: "task",
             item_id: task.id,
             user_id: user_id,
             actor_id: actor_id,
             context: build_task_notification_context(task)
           }) do
        {:ok, notification} ->
          notification = Repo.preload(notification, [:actor])
          Mentions.broadcast_notification(notification)

        _ ->
          :ok
      end
    else
      _ -> :ok
    end
  end

  defp build_task_notification_context(task) do
    context = %{taskId: task.id, taskTitle: task.title, boardId: task.list_id}

    if task.parent_id do
      Map.put(context, :parentTaskId, task.parent_id)
    else
      context
    end
  end

  def delete(conn, _params) do
    with {:ok, _task} <- Lists.delete_task(conn.assigns.task) do
      send_resp(conn, :no_content, "")
    end
  end

  def reorder(conn, %{"position" => position} = params) do
    new_status_id = params["status_id"]

    with {:ok, task} <- Lists.reorder_task(conn.assigns.task, position, new_status_id) do
      render(conn, :show, task: task)
    end
  end
end
