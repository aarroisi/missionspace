defmodule BridgeWeb.ListController do
  use BridgeWeb, :controller

  alias Bridge.Lists
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
    case Lists.get_list(conn.params["id"], conn.assigns.workspace_id) do
      {:ok, list} ->
        assign(conn, :list, list)

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
    conn.assigns[:list]
  end

  def index(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    opts = build_pagination_opts(params)
    page = Lists.list_lists(workspace_id, user, opts)
    entries = Bridge.Stars.mark_starred(page.entries, user.id, "board")

    render(conn, :index, page: %{page | entries: entries})
  end

  def create(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    list_params =
      params
      |> Map.put("workspace_id", workspace_id)
      |> Map.put("created_by_id", user.id)

    with {:ok, list} <- Lists.create_list(list_params) do
      # Preload created_by for the response
      list = Bridge.Repo.preload(list, :created_by)

      conn
      |> put_status(:created)
      |> render(:show, list: list)
    end
  end

  def show(conn, _params) do
    user = conn.assigns.current_user
    list = Bridge.Stars.mark_starred(conn.assigns.list, user.id, "board")
    tasks = Bridge.Stars.mark_starred(list.tasks, user.id, "task")
    render(conn, :show, list: %{list | tasks: tasks})
  end

  def update(conn, params) do
    # Remove id from params since it's already in the resource
    list_params = Map.drop(params, ["id"])

    with {:ok, list} <- Lists.update_list(conn.assigns.list, list_params) do
      render(conn, :show, list: list)
    end
  end

  def delete(conn, _params) do
    with {:ok, _list} <- Lists.delete_list(conn.assigns.list) do
      send_resp(conn, :no_content, "")
    end
  end

  def suggest_prefix(conn, %{"name" => name}) do
    workspace_id = conn.assigns.workspace_id
    prefix = Lists.suggest_prefix(name, workspace_id)
    json(conn, %{data: %{prefix: prefix}})
  end

  def check_prefix(conn, %{"prefix" => prefix}) do
    workspace_id = conn.assigns.workspace_id
    available = Lists.check_prefix_available?(String.upcase(prefix), workspace_id)
    json(conn, %{data: %{available: available}})
  end
end
