defmodule Missionspace.Accounts.DeviceSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  schema "device_sessions" do
    field(:token_hash, :string)
    field(:last_seen_at, :utc_datetime_usec)

    has_many(:accounts, Missionspace.Accounts.DeviceSessionAccount)

    timestamps()
  end

  def create_changeset(device_session, attrs) do
    device_session
    |> cast(attrs, [:token_hash, :last_seen_at])
    |> validate_required([:token_hash])
    |> unique_constraint(:token_hash)
  end

  def touch_changeset(device_session) do
    change(device_session, last_seen_at: DateTime.utc_now())
  end
end
