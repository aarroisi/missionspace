defmodule MissionspaceWeb.Plugs.AuthorizePlug do
  @moduledoc """
  Plug for authorizing actions in controllers.

  Usage in controllers:
    plug :authorize, :manage_workspace_members when action in [:index, :create, :update, :delete]
    plug :authorize, :view_item when action in [:show]

  The plug checks permissions against the current user and resource.
  Resources are loaded from conn.assigns based on the permission type.
  """

  import Plug.Conn
  alias Missionspace.Authorization.Policy

  def init(opts), do: opts

  def call(conn, permission) do
    user = conn.assigns.current_user
    resource = get_resource(conn, permission)

    if Policy.can?(user, permission, resource) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Forbidden"})
      |> halt()
    end
  end

  # Get resource from conn.assigns based on permission type
  defp get_resource(conn, permission) do
    case permission do
      :view_project -> conn.assigns[:project]
      :view_item -> get_item_resource(conn)
      :update_item -> get_item_resource(conn)
      :delete_item -> get_item_resource(conn)
      :create_item -> get_project_id_for_create(conn)
      :comment -> get_item_resource(conn)
      _ -> nil
    end
  end

  # Get the item resource from assigns (doc, list, channel, task, etc.)
  defp get_item_resource(conn) do
    conn.assigns[:doc] ||
      conn.assigns[:list] ||
      conn.assigns[:channel] ||
      conn.assigns[:task]
  end

  # Get project_id from params for create actions
  defp get_project_id_for_create(conn) do
    conn.params["project_id"] || get_in(conn.params, ["doc", "project_id"]) ||
      get_in(conn.params, ["list", "project_id"]) ||
      get_in(conn.params, ["channel", "project_id"])
  end
end
