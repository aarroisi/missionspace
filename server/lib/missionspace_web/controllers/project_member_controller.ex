defmodule MissionspaceWeb.ProjectMemberController do
  use MissionspaceWeb, :controller

  alias Missionspace.Projects
  alias Missionspace.Accounts
  alias Missionspace.Authorization.Policy

  action_fallback(MissionspaceWeb.FallbackController)

  plug(:authorize)

  def index(conn, %{"project_id" => project_id}) do
    members = Projects.list_members(project_id)
    render(conn, :index, members: members)
  end

  def create(conn, %{"project_id" => project_id, "user_id" => user_id}) do
    workspace_id = conn.assigns.workspace_id

    with {:ok, _user} <- Accounts.get_workspace_user(user_id, workspace_id),
         :ok <- validate_guest_project_limit(user_id, workspace_id),
         {:ok, project_member} <- Projects.add_member(project_id, user_id) do
      conn
      |> put_status(:created)
      |> render(:show, member: project_member)
    end
  end

  def delete(conn, %{"project_id" => project_id, "id" => user_id}) do
    with {:ok, _member} <- Projects.remove_member(project_id, user_id) do
      send_resp(conn, :no_content, "")
    end
  end

  # Guests can only be in one project or item total
  defp validate_guest_project_limit(user_id, workspace_id) do
    case Accounts.get_workspace_user(user_id, workspace_id) do
      {:ok, %{role: "guest"}} ->
        if Projects.guest_membership_count(user_id) == 0 do
          :ok
        else
          {:error, :guest_project_limit}
        end

      {:ok, _user} ->
        :ok

      error ->
        error
    end
  end

  defp authorize(conn, _opts) do
    user = conn.assigns.current_user

    if Policy.can?(user, :manage_project_members, nil) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Forbidden"})
      |> halt()
    end
  end
end
