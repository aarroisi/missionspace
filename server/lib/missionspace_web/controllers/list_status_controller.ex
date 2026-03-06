defmodule MissionspaceWeb.ListStatusController do
  use MissionspaceWeb, :controller

  alias Missionspace.Lists
  import Plug.Conn

  action_fallback(MissionspaceWeb.FallbackController)

  plug(:load_list when action in [:index, :create, :reorder])
  plug(:load_status when action in [:update, :delete])

  defp load_list(conn, _opts) do
    list_id = conn.params["list_id"]
    workspace_id = conn.assigns.workspace_id

    case Lists.get_list(list_id, workspace_id) do
      {:ok, list} ->
        assign(conn, :list, list)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  defp load_status(conn, _opts) do
    status_id = conn.params["id"]
    workspace_id = conn.assigns.workspace_id

    case Lists.get_status(status_id) do
      {:ok, status} ->
        # Verify the status belongs to a list in the user's workspace
        case Lists.get_list(status.list_id, workspace_id) do
          {:ok, _list} ->
            assign(conn, :status, status)

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

  def index(conn, _params) do
    list = conn.assigns.list
    statuses = Lists.list_statuses(list.id)
    render(conn, :index, statuses: statuses)
  end

  def create(conn, params) do
    list = conn.assigns.list

    status_params =
      params
      |> Map.put("list_id", list.id)

    with {:ok, status} <- Lists.create_status(status_params) do
      conn
      |> put_status(:created)
      |> render(:show, status: status)
    end
  end

  def update(conn, params) do
    status = conn.assigns.status
    status_params = Map.drop(params, ["id"])

    with {:ok, updated_status} <- Lists.update_status(status, status_params) do
      render(conn, :show, status: updated_status)
    end
  end

  def delete(conn, _params) do
    status = conn.assigns.status

    case Lists.delete_status(status) do
      {:ok, _status} ->
        send_resp(conn, :no_content, "")

      {:error, :is_done_status} ->
        conn
        |> put_status(:unprocessable_entity)
        |> Phoenix.Controller.json(%{
          error: "Cannot delete the DONE status."
        })

      {:error, :has_tasks} ->
        conn
        |> put_status(:unprocessable_entity)
        |> Phoenix.Controller.json(%{
          error: "Cannot delete status that has tasks. Move or delete the tasks first."
        })
    end
  end

  def reorder(conn, %{"status_ids" => status_ids}) do
    list = conn.assigns.list

    case Lists.reorder_statuses(list.id, status_ids) do
      {:ok, statuses} ->
        render(conn, :index, statuses: statuses)

      {:error, :done_must_be_last} ->
        conn
        |> put_status(:unprocessable_entity)
        |> Phoenix.Controller.json(%{
          error: "The DONE status must always be at the end."
        })
    end
  end
end
