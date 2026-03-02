defmodule BridgeWeb.ProjectController do
  use BridgeWeb, :controller

  alias Bridge.Projects
  alias Bridge.Authorization.Policy
  import BridgeWeb.PaginationHelpers
  import Plug.Conn

  action_fallback(BridgeWeb.FallbackController)

  plug(:load_resource when action in [:show, :update, :delete])
  plug(:authorize, :view_project when action in [:show])
  plug(:authorize, :manage_projects when action in [:create, :update, :delete])

  defp load_resource(conn, _opts) do
    case Projects.get_project_with_items(conn.params["id"], conn.assigns.workspace_id) do
      {:ok, project} ->
        assign(conn, :project, project)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  defp authorize(conn, permission) do
    user = conn.assigns.current_user
    resource = conn.assigns[:project]

    if Policy.can?(user, permission, resource) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Forbidden"})
      |> halt()
    end
  end

  def index(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    opts = build_pagination_opts(params)
    page = Projects.list_projects_with_items(workspace_id, user, opts)
    entries = Bridge.Stars.mark_starred(page.entries, user.id, "project")

    render(conn, :index, page: %{page | entries: entries})
  end

  def create(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user
    member_ids = Map.get(params, "member_ids", [])

    project_params =
      params
      |> Map.put("workspace_id", workspace_id)
      |> Map.put("created_by_id", user.id)
      |> Map.delete("member_ids")

    with {:ok, project} <- Projects.create_project(project_params) do
      # Add members to the project
      Enum.each(member_ids, fn user_id ->
        Projects.add_member(project.id, user_id)
      end)

      # Preload created_by for the response
      project = Bridge.Repo.preload(project, :created_by)

      conn
      |> put_status(:created)
      |> render(:show, project: project)
    end
  end

  def show(conn, _params) do
    user = conn.assigns.current_user
    project = Bridge.Stars.mark_starred(conn.assigns.project, user.id, "project")
    render(conn, :show, project: project)
  end

  def update(conn, params) do
    with {:ok, project} <- Projects.update_project(conn.assigns.project, params) do
      project = Bridge.Repo.preload(project, :created_by)
      render(conn, :show, project: project)
    end
  end

  def delete(conn, _params) do
    with {:ok, _project} <- Projects.delete_project(conn.assigns.project) do
      send_resp(conn, :no_content, "")
    end
  end
end
