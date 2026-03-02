defmodule BridgeWeb.ItemMemberController do
  use BridgeWeb, :controller

  alias Bridge.Projects
  alias Bridge.Accounts
  alias Bridge.Authorization.Policy
  import Plug.Conn

  action_fallback(BridgeWeb.FallbackController)

  plug(:load_and_authorize)

  def index(conn, _params) do
    %{item_type: item_type, item_id: item_id} = conn.assigns.item_ref
    members = Projects.list_item_members(item_type, item_id)
    render(conn, :index, members: members)
  end

  def create(conn, %{"user_id" => user_id}) do
    %{item_type: item_type, item_id: item_id} = conn.assigns.item_ref
    workspace_id = conn.assigns.workspace_id

    with {:ok, _user} <- Accounts.get_workspace_user(user_id, workspace_id),
         :ok <- validate_guest_item_limit(user_id, workspace_id),
         {:ok, member} <-
           Projects.add_item_member(%{
             item_type: item_type,
             item_id: item_id,
             user_id: user_id,
             workspace_id: workspace_id
           }) do
      member = Bridge.Repo.preload(member, :user)

      conn
      |> put_status(:created)
      |> render(:show, member: member)
    end
  end

  def delete(conn, %{"user_id" => user_id}) do
    %{item_type: item_type, item_id: item_id} = conn.assigns.item_ref

    with {:ok, _member} <- Projects.remove_item_member(item_type, item_id, user_id) do
      send_resp(conn, :no_content, "")
    end
  end

  defp load_and_authorize(conn, _opts) do
    item_type = conn.params["item_type"]
    item_id = conn.params["item_id"]
    user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id

    with {:ok, item} <- load_item(item_type, item_id, workspace_id),
         nil <- Projects.get_item_project_id(item_type, item_id),
         true <- Policy.can?(user, :manage_item_members, item) do
      assign(conn, :item_ref, %{item_type: item_type, item_id: item_id})
    else
      project_id when is_binary(project_id) ->
        conn
        |> put_status(:unprocessable_entity)
        |> Phoenix.Controller.json(%{
          errors: %{
            detail:
              "Cannot manage members for items that belong to a project. Manage members at the project level instead."
          }
        })
        |> halt()

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()

      false ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{error: "Forbidden"})
        |> halt()
    end
  end

  defp load_item("list", id, workspace_id), do: Bridge.Lists.get_list(id, workspace_id)
  defp load_item("doc_folder", id, workspace_id), do: Bridge.Docs.get_doc_folder(id, workspace_id)
  defp load_item("channel", id, workspace_id), do: Bridge.Chat.get_channel(id, workspace_id)
  defp load_item(_, _, _), do: {:error, :not_found}

  # Guests can only be in one project or item total
  defp validate_guest_item_limit(user_id, workspace_id) do
    case Accounts.get_workspace_user(user_id, workspace_id) do
      {:ok, %{role: "guest"}} ->
        if Projects.guest_membership_count(user_id) == 0 do
          :ok
        else
          {:error, :guest_item_limit}
        end

      {:ok, _user} ->
        :ok

      error ->
        error
    end
  end
end
