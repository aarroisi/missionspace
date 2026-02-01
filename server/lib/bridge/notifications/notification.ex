defmodule Bridge.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "notifications" do
    field(:type, :string)
    field(:entity_type, :string)
    field(:entity_id, :binary_id)
    field(:context, :map, default: %{})
    field(:read, :boolean, default: false)

    belongs_to(:user, Bridge.Accounts.User)
    belongs_to(:actor, Bridge.Accounts.User)

    timestamps()
  end

  @notification_types ["mention"]
  @entity_types ["message", "doc", "task", "subtask"]

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :entity_type, :entity_id, :context, :read, :user_id, :actor_id])
    |> validate_required([:type, :entity_type, :entity_id, :user_id, :actor_id])
    |> validate_inclusion(:type, @notification_types)
    |> validate_inclusion(:entity_type, @entity_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
  end

  @doc false
  def mark_as_read_changeset(notification) do
    change(notification, read: true)
  end
end
