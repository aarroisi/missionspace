defmodule Missionspace.PushNotifications do
  @moduledoc """
  Handles Web Push notification subscriptions and delivery.
  Uses VAPID-based Web Push protocol.
  """

  import Ecto.Query
  alias Missionspace.Repo
  alias Missionspace.Notifications.PushSubscription

  @doc """
  Subscribe a user's device to push notifications.
  Upserts by (user_id, endpoint) to avoid duplicates.
  """
  def subscribe(user_id, %{endpoint: endpoint, p256dh: p256dh, auth: auth}) do
    attrs = %{user_id: user_id, endpoint: endpoint, p256dh: p256dh, auth: auth}

    %PushSubscription{}
    |> PushSubscription.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:p256dh, :auth, :updated_at]},
      conflict_target: [:user_id, :endpoint],
      returning: true
    )
  end

  @doc """
  Unsubscribe a user's device from push notifications.
  """
  def unsubscribe(user_id, endpoint) do
    query =
      from(ps in PushSubscription,
        where: ps.user_id == ^user_id and ps.endpoint == ^endpoint
      )

    case Repo.delete_all(query) do
      {count, _} when count > 0 -> :ok
      _ -> {:error, :not_found}
    end
  end

  @doc """
  List all push subscriptions for a user.
  """
  def get_subscriptions(user_id) do
    from(ps in PushSubscription, where: ps.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Send a web push notification to all of a user's subscribed devices.
  Silently removes expired/invalid subscriptions (404/410 responses).
  """
  def send_web_push(user_id, payload) when is_map(payload) do
    subscriptions = get_subscriptions(user_id)

    if subscriptions == [] do
      :ok
    else
      json_payload = Jason.encode!(payload)

      Enum.each(subscriptions, fn sub ->
        push_subscription = %{
          endpoint: sub.endpoint,
          keys: %{p256dh: sub.p256dh, auth: sub.auth}
        }

        case WebPushEncryption.send_web_push(json_payload, push_subscription) do
          {:ok, %{status_code: status}} when status in [201, 200] ->
            :ok

          {:ok, %{status_code: status}} when status in [404, 410] ->
            # Subscription expired or invalid, clean it up
            Repo.delete(sub)

          _ ->
            :ok
        end
      end)
    end
  end

  @doc """
  Returns the VAPID public key from application config.
  """
  def vapid_public_key do
    case Application.get_env(:web_push_encryption, :vapid_details) do
      nil -> nil
      details -> Keyword.get(details, :public_key)
    end
  end
end
