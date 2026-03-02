defmodule BridgeWeb.DocFolderController do
  use BridgeWeb, :controller

  alias Bridge.Docs
  alias Bridge.Namespaces
  alias Bridge.Authorization.Policy
  import BridgeWeb.PaginationHelpers
  import Plug.Conn

  action_fallback(BridgeWeb.FallbackController)

  plug(:load_resource when action in [:show, :update, :delete])
  plug(:authorize, :view_item when action in [:show])
  plug(:authorize, :create_item when action in [:create])
  plug(:authorize, :update_item when action in [:update])
  plug(:authorize, :delete_item when action in [:delete])

  defp load_resource(conn, _opts) do
    case Docs.get_doc_folder(conn.params["id"], conn.assigns.workspace_id) do
      {:ok, folder} ->
        assign(conn, :doc_folder, folder)

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
    conn.params["project_id"]
  end

  defp get_authorization_resource(conn, _permission) do
    conn.assigns[:doc_folder]
  end

  def index(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    opts = build_pagination_opts(params)
    page = Docs.list_doc_folders(workspace_id, user, opts)
    entries = Bridge.Stars.mark_starred(page.entries, user.id, "doc_folder")

    render(conn, :index, page: %{page | entries: entries})
  end

  def create(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    folder_params =
      params
      |> Map.put("workspace_id", workspace_id)
      |> Map.put("created_by_id", user.id)

    with {:ok, folder} <- Docs.create_doc_folder(folder_params) do
      conn
      |> put_status(:created)
      |> render(:show, doc_folder: folder)
    end
  end

  def show(conn, _params) do
    user = conn.assigns.current_user
    folder = Bridge.Stars.mark_starred(conn.assigns.doc_folder, user.id, "doc_folder")
    render(conn, :show, doc_folder: folder)
  end

  def update(conn, params) do
    folder_params = Map.drop(params, ["id"])

    with {:ok, folder} <- Docs.update_doc_folder(conn.assigns.doc_folder, folder_params) do
      render(conn, :show, doc_folder: folder)
    end
  end

  def delete(conn, _params) do
    with {:ok, _folder} <- Docs.delete_doc_folder(conn.assigns.doc_folder) do
      send_resp(conn, :no_content, "")
    end
  end

  def suggest_prefix(conn, %{"name" => name}) do
    workspace_id = conn.assigns.workspace_id
    prefix = Namespaces.suggest_prefix(name, workspace_id)
    json(conn, %{data: %{prefix: prefix}})
  end

  def check_prefix(conn, %{"prefix" => prefix}) do
    workspace_id = conn.assigns.workspace_id
    available = Namespaces.check_prefix_available?(String.upcase(prefix), workspace_id)
    json(conn, %{data: %{available: available}})
  end
end
