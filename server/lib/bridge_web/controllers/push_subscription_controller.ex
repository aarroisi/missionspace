defmodule BridgeWeb.PushSubscriptionController do
  use BridgeWeb, :controller

  alias Bridge.PushNotifications

  action_fallback(BridgeWeb.FallbackController)

  @doc """
  GET /api/push/vapid-key
  Returns the VAPID public key for the frontend to subscribe.
  """
  def vapid_key(conn, _params) do
    case PushNotifications.vapid_public_key() do
      nil ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "Push notifications not configured"})

      key ->
        json(conn, %{data: %{vapid_public_key: key}})
    end
  end

  @doc """
  POST /api/push/subscribe
  Registers a push subscription for the current user.
  """
  def subscribe(conn, %{"endpoint" => endpoint, "p256dh" => p256dh, "auth" => auth}) do
    current_user = conn.assigns.current_user

    with {:ok, _subscription} <-
           PushNotifications.subscribe(current_user.id, %{
             endpoint: endpoint,
             p256dh: p256dh,
             auth: auth
           }) do
      conn
      |> put_status(:created)
      |> json(%{data: %{subscribed: true}})
    end
  end

  @doc """
  DELETE /api/push/subscribe
  Unregisters a push subscription for the current user.
  """
  def unsubscribe(conn, %{"endpoint" => endpoint}) do
    current_user = conn.assigns.current_user

    case PushNotifications.unsubscribe(current_user.id, endpoint) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        send_resp(conn, :no_content, "")
    end
  end
end
