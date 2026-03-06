defmodule Missionspace.Accounts.DeviceSessionAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  schema "device_session_accounts" do
    field(:session_token_hash, :string)
    field(:session_token_expires_at, :utc_datetime_usec)
    field(:signed_out_at, :utc_datetime_usec)
    field(:last_used_at, :utc_datetime_usec)
    field(:last_authenticated_at, :utc_datetime_usec)

    belongs_to(:device_session, Missionspace.Accounts.DeviceSession)
    belongs_to(:user, Missionspace.Accounts.User)

    timestamps()
  end

  def changeset(device_session_account, attrs) do
    device_session_account
    |> cast(attrs, [
      :session_token_hash,
      :session_token_expires_at,
      :signed_out_at,
      :last_used_at,
      :last_authenticated_at,
      :device_session_id,
      :user_id
    ])
    |> validate_required([:device_session_id, :user_id])
    |> unique_constraint([:device_session_id, :user_id])
  end
end
