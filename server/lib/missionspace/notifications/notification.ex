defmodule Missionspace.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "notifications" do
    field(:type, :string)
    field(:entity_type, :string)
    field(:entity_id, :binary_id)
    field(:item_type, :string)
    field(:item_id, :binary_id)
    field(:thread_id, :binary_id)
    field(:latest_message_id, :binary_id)
    field(:event_count, :integer, default: 1)
    field(:context, :map, default: %{})
    field(:read, :boolean, default: false)

    belongs_to(:user, Missionspace.Accounts.User)
    belongs_to(:actor, Missionspace.Accounts.User)

    timestamps()
  end

  @notification_types ["mention", "comment", "thread_reply"]
  @item_types ["task", "doc", "channel", "dm"]

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :type,
      :entity_type,
      :entity_id,
      :item_type,
      :item_id,
      :thread_id,
      :latest_message_id,
      :event_count,
      :context,
      :read,
      :user_id,
      :actor_id
    ])
    |> validate_required([:type, :item_type, :item_id, :user_id, :actor_id])
    |> validate_inclusion(:type, @notification_types)
    |> validate_inclusion(:item_type, @item_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
  end

  @doc false
  def mark_as_read_changeset(notification) do
    change(notification, read: true)
  end
end
