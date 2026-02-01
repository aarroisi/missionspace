defmodule BridgeWeb.SubtaskController do
  use BridgeWeb, :controller

  alias Bridge.Lists
  import Plug.Conn

  action_fallback(BridgeWeb.FallbackController)

  plug(:load_resource when action in [:show, :update, :delete])
  plug(:verify_workspace_access_for_create when action in [:create])

  defp load_resource(conn, _opts) do
    workspace_id = conn.assigns.workspace_id

    case Lists.get_subtask(conn.params["id"]) do
      {:ok, subtask} ->
        # Verify the subtask's task's list belongs to user's workspace
        case Lists.get_list(subtask.task.list_id, workspace_id) do
          {:ok, _list} ->
            assign(conn, :subtask, subtask)

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
            |> halt()
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  # Verify the task belongs to a list in the user's workspace (for create)
  defp verify_workspace_access_for_create(conn, _opts) do
    task_id = conn.params["task_id"]
    workspace_id = conn.assigns.workspace_id

    if task_id do
      case Lists.get_task(task_id) do
        {:ok, task} ->
          # Check if the task's list belongs to the user's workspace
          case Lists.get_list(task.list_id, workspace_id) do
            {:ok, _list} ->
              conn

            {:error, :not_found} ->
              conn
              |> put_status(:not_found)
              |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
              |> halt()
          end

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
          |> halt()
      end
    else
      conn
      |> put_status(:bad_request)
      |> Phoenix.Controller.json(%{errors: %{detail: "task_id is required"}})
      |> halt()
    end
  end

  def index(conn, %{"task_id" => task_id}) do
    subtasks = Lists.list_subtasks(task_id)
    render(conn, :index, subtasks: subtasks)
  end

  def index(conn, %{"assigned_to_me" => "true"}) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id
    subtasks = Lists.list_subtasks_by_assignee(current_user.id, workspace_id)
    render(conn, :index, subtasks: subtasks)
  end

  def index(conn, _params) do
    subtasks = []
    render(conn, :index, subtasks: subtasks)
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user
    subtask_params = Map.put(params, "created_by_id", current_user.id)

    with {:ok, subtask} <- Lists.create_subtask(subtask_params) do
      conn
      |> put_status(:created)
      |> render(:show, subtask: subtask)
    end
  end

  def show(conn, _params) do
    render(conn, :show, subtask: conn.assigns.subtask)
  end

  def update(conn, params) do
    subtask_params = Map.drop(params, ["id"])

    with {:ok, subtask} <- Lists.update_subtask(conn.assigns.subtask, subtask_params) do
      render(conn, :show, subtask: subtask)
    end
  end

  def delete(conn, _params) do
    with {:ok, _subtask} <- Lists.delete_subtask(conn.assigns.subtask) do
      send_resp(conn, :no_content, "")
    end
  end
end
