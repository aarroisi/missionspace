defmodule Missionspace.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:avatar, :string)
    field(:timezone, :string)
    field(:online, :boolean, default: false)
    field(:password_hash, :string)
    field(:password, :string, virtual: true)
    field(:role, :string, default: "owner")
    field(:scopes, {:array, :string}, virtual: true)
    field(:is_active, :boolean, default: true)
    field(:deleted_at, :utc_datetime_usec)
    field(:email_verified_at, :utc_datetime_usec)
    field(:email_verification_token, :string)
    field(:password_reset_token, :string)
    field(:password_reset_expires_at, :utc_datetime_usec)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)
    has_many(:project_members, Missionspace.Projects.ProjectMember)
    has_many(:projects, through: [:project_members, :project])
    has_many(:api_keys, Missionspace.ApiKeys.ApiKey)

    timestamps()
  end

  @roles ["owner", "member", "guest"]

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :email,
      :avatar,
      :timezone,
      :online,
      :workspace_id,
      :role,
      :is_active,
      :deleted_at
    ])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:timezone, max: 100)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password, :workspace_id, :role, :timezone])
    |> validate_required([:name, :email, :password, :workspace_id])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:timezone, max: 100)
    |> validate_length(:password, min: 6)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
    |> put_password_hash()
    |> put_change(:email_verification_token, generate_token())
  end

  def password_reset_changeset(user) do
    user
    |> change(%{
      password_reset_token: generate_token(),
      password_reset_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    })
  end

  def reset_password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 6)
    |> put_password_hash()
    |> put_change(:password_reset_token, nil)
    |> put_change(:password_reset_expires_at, nil)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, hash_password(password))
    end
  end

  def hash_password(password) do
    :crypto.hash(:sha256, password) |> Base.encode16(case: :lower)
  end

  def verify_password(user, password) do
    hash_password(password) == user.password_hash
  end
end
