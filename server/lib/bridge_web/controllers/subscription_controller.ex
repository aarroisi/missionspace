defmodule BridgeWeb.SubscriptionController do
  use BridgeWeb, :controller

  alias Bridge.Subscriptions
  import Plug.Conn

  action_fallback(BridgeWeb.FallbackController)

  @doc """
  GET /api/subscriptions/:item_type/:item_id
  Lists subscribers for an item.
  """
  def index(conn, %{"item_type" => item_type, "item_id" => item_id}) do
    subscribers = Subscriptions.list_subscribers(item_type, item_id)
    render(conn, :index, subscribers: subscribers)
  end

  @doc """
  GET /api/subscriptions/:item_type/:item_id/status
  Returns whether the current user is subscribed to the item.
  """
  def status(conn, %{"item_type" => item_type, "item_id" => item_id}) do
    current_user = conn.assigns.current_user
    subscribed = Subscriptions.subscribed?(item_type, item_id, current_user.id)
    json(conn, %{data: %{subscribed: subscribed}})
  end

  @doc """
  POST /api/subscriptions/:item_type/:item_id
  Subscribes the current user to an item.
  """
  def create(conn, %{"item_type" => item_type, "item_id" => item_id}) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id

    with {:ok, subscription} <-
           Subscriptions.subscribe(%{
             item_type: item_type,
             item_id: item_id,
             user_id: current_user.id,
             workspace_id: workspace_id
           }) do
      subscription = Bridge.Repo.preload(subscription, :user)

      conn
      |> put_status(:created)
      |> render(:show, subscription: subscription)
    end
  end

  @doc """
  DELETE /api/subscriptions/:item_type/:item_id
  Unsubscribes the current user from an item.
  """
  def delete(conn, %{"item_type" => item_type, "item_id" => item_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _subscription} <-
           Subscriptions.unsubscribe(item_type, item_id, current_user.id) do
      send_resp(conn, :no_content, "")
    end
  end
end
