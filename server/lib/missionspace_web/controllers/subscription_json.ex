defmodule MissionspaceWeb.SubscriptionJSON do
  alias Missionspace.Subscriptions.Subscription

  def index(%{subscribers: subscribers}) do
    %{data: for(subscription <- subscribers, do: data(subscription))}
  end

  def show(%{subscription: subscription}) do
    %{data: data(subscription)}
  end

  defp data(%Subscription{} = subscription) do
    %{
      id: subscription.id,
      item_type: subscription.item_type,
      item_id: subscription.item_id,
      user_id: subscription.user_id,
      user:
        if(Ecto.assoc_loaded?(subscription.user),
          do: %{
            id: subscription.user.id,
            name: subscription.user.name,
            email: subscription.user.email,
            avatar: subscription.user.avatar
          },
          else: nil
        ),
      inserted_at: subscription.inserted_at
    }
  end
end
