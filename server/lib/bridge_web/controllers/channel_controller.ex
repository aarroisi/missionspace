defmodule BridgeWeb.ChannelController do
  use BridgeWeb, :controller

  alias Bridge.Chat
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
    case Chat.get_channel(conn.params["id"], conn.assigns.workspace_id) do
      {:ok, channel} ->
        assign(conn, :channel, channel)

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
    conn.assigns[:channel]
  end

  def index(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    opts = build_pagination_opts(params)
    page = Chat.list_channels(workspace_id, user, opts)
    entries = Bridge.Stars.mark_starred(page.entries, user.id, "channel")

    render(conn, :index, page: %{page | entries: entries})
  end

  def create(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    channel_params =
      params
      |> Map.put("workspace_id", workspace_id)
      |> Map.put("created_by_id", user.id)

    with {:ok, channel} <- Chat.create_channel(channel_params) do
      conn
      |> put_status(:created)
      |> render(:show, channel: channel)
    end
  end

  def show(conn, _params) do
    user = conn.assigns.current_user
    channel = Bridge.Stars.mark_starred(conn.assigns.channel, user.id, "channel")
    render(conn, :show, channel: channel)
  end

  def update(conn, params) do
    with {:ok, channel} <- Chat.update_channel(conn.assigns.channel, params) do
      render(conn, :show, channel: channel)
    end
  end

  def delete(conn, _params) do
    with {:ok, _channel} <- Chat.delete_channel(conn.assigns.channel) do
      send_resp(conn, :no_content, "")
    end
  end
end
