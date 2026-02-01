defmodule BridgeWeb.NotificationController do
  use BridgeWeb, :controller

  alias Bridge.Notifications
  import Plug.Conn

  action_fallback(BridgeWeb.FallbackController)

  plug(:load_resource when action in [:mark_as_read])

  defp load_resource(conn, _opts) do
    current_user = conn.assigns.current_user

    case Notifications.get_notification(conn.params["id"], current_user.id) do
      {:ok, notification} ->
        assign(conn, :notification, notification)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  @doc """
  GET /api/notifications
  Lists notifications for the current user, paginated with unread first.
  """
  def index(conn, params) do
    current_user = conn.assigns.current_user
    opts = BridgeWeb.PaginationHelpers.build_pagination_opts(params)
    page = Notifications.list_notifications(current_user.id, opts)
    render(conn, :index, page: page)
  end

  @doc """
  PATCH /api/notifications/:id/read
  Marks a single notification as read.
  """
  def mark_as_read(conn, _params) do
    with {:ok, notification} <- Notifications.mark_as_read(conn.assigns.notification.id) do
      render(conn, :show, notification: notification)
    end
  end

  @doc """
  POST /api/notifications/read-all
  Marks all notifications as read for the current user.
  """
  def mark_all_as_read(conn, _params) do
    current_user = conn.assigns.current_user
    {count, _} = Notifications.mark_all_as_read(current_user.id)
    json(conn, %{data: %{marked_count: count}})
  end

  @doc """
  GET /api/notifications/unread-count
  Returns the count of unread notifications for the current user.
  """
  def unread_count(conn, _params) do
    current_user = conn.assigns.current_user
    count = Notifications.get_unread_count(current_user.id)
    json(conn, %{data: %{count: count}})
  end
end
