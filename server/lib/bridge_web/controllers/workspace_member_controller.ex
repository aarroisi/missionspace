defmodule BridgeWeb.WorkspaceMemberController do
  use BridgeWeb, :controller

  alias Bridge.Accounts
  alias Bridge.Authorization.Policy

  action_fallback(BridgeWeb.FallbackController)

  # Only require manage permission for create/update/delete, not index/show
  plug(:authorize when action in [:create, :update, :delete])

  def index(conn, _params) do
    workspace_id = conn.assigns.workspace_id
    members = Accounts.list_workspace_users(workspace_id)
    render(conn, :index, members: members)
  end

  def show(conn, %{"id" => id}) do
    workspace_id = conn.assigns.workspace_id

    with {:ok, user} <- Accounts.get_workspace_user(id, workspace_id) do
      render(conn, :show, member: user)
    end
  end

  def create(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user_params = Map.put(params, "workspace_id", workspace_id)

    with {:ok, user} <- Accounts.create_user(user_params) do
      conn
      |> put_status(:created)
      |> render(:show, member: user)
    end
  end

  def update(conn, %{"id" => id} = params) do
    workspace_id = conn.assigns.workspace_id

    with {:ok, user} <- Accounts.get_workspace_user(id, workspace_id),
         {:ok, user} <- Accounts.update_user(user, params) do
      render(conn, :show, member: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    workspace_id = conn.assigns.workspace_id

    with {:ok, user} <- Accounts.get_workspace_user(id, workspace_id),
         {:ok, _user} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  defp authorize(conn, _opts) do
    user = conn.assigns.current_user

    if Policy.can?(user, :manage_workspace_members, nil) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Forbidden"})
      |> halt()
    end
  end
end
