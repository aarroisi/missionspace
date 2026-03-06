defmodule Missionspace.Accounts.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "workspaces" do
    field(:name, :string)
    field(:slug, :string)
    field(:logo, :string)
    field(:storage_used_bytes, :integer, default: 0)
    field(:storage_quota_bytes, :integer, default: 5_368_709_120)

    has_many(:users, Missionspace.Accounts.User)
    has_many(:assets, Missionspace.Assets.Asset)

    timestamps()
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :logo])
    |> validate_required([:name])
    |> unique_constraint(:slug)
  end

  def registration_changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase letters, numbers, and hyphens only"
    )
    |> validate_length(:slug, min: 3, max: 30)
    |> unique_constraint(:slug)
    |> put_slug()
  end

  defp put_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        slug =
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9-]/, "-")
          |> String.replace(~r/-+/, "-")
          |> String.trim("-")

        put_change(changeset, :slug, slug)
    end
  end
end
