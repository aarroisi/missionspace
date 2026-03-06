defmodule Missionspace.ApiKeys.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  schema "api_keys" do
    field(:name, :string)
    field(:key_hash, :string)
    field(:key_prefix, :string)
    field(:scopes, {:array, :string}, default: [])
    field(:last_used_at, :utc_datetime_usec)
    field(:revoked_at, :utc_datetime_usec)

    belongs_to(:user, Missionspace.Accounts.User)

    timestamps()
  end

  @doc false
  def create_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :key_hash, :key_prefix, :scopes, :user_id])
    |> validate_required([:name, :key_hash, :key_prefix, :scopes, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:key_hash)
  end

  @doc false
  def scopes_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:scopes])
    |> validate_required([:scopes])
  end

  @doc false
  def revoke_changeset(api_key) do
    change(api_key, revoked_at: DateTime.utc_now())
  end

  @doc false
  def touch_last_used_changeset(api_key) do
    change(api_key, last_used_at: DateTime.utc_now())
  end
end
