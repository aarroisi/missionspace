defmodule BridgeWeb.NotificationChannel do
  use BridgeWeb, :channel

  @impl true
  def join("notifications:" <> user_id, _payload, socket) do
    # Only allow users to join their own notification channel
    if socket.assigns.user_id == user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Broadcast a new notification to a user
  def broadcast_notification(user_id, notification) do
    BridgeWeb.Endpoint.broadcast("notifications:#{user_id}", "new_notification", notification)
  end
end
