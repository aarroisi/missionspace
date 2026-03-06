defmodule Missionspace.Notifications.PushSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "push_subscriptions" do
    field(:endpoint, :string)
    field(:p256dh, :string)
    field(:auth, :string)

    belongs_to(:user, Missionspace.Accounts.User)

    timestamps()
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:endpoint, :p256dh, :auth, :user_id])
    |> validate_required([:endpoint, :p256dh, :auth, :user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :endpoint])
  end
end
