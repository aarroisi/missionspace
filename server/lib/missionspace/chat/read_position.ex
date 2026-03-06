defmodule Missionspace.Chat.ReadPosition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_item_types ["channel", "dm"]

  schema "read_positions" do
    field(:item_type, :string)
    field(:item_id, Ecto.UUID)
    field(:last_read_at, :utc_datetime_usec)

    belongs_to(:user, Missionspace.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(read_position, attrs) do
    read_position
    |> cast(attrs, [:item_type, :item_id, :user_id, :last_read_at])
    |> validate_required([:item_type, :item_id, :user_id, :last_read_at])
    |> validate_inclusion(:item_type, @valid_item_types)
    |> unique_constraint([:item_type, :item_id, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
