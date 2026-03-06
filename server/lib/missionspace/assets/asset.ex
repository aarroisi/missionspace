defmodule Missionspace.Assets.Asset do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @asset_types ["avatar", "file"]
  @statuses ["pending", "active"]
  @attachable_types ["doc", "message", "user", "task", "channel", "dm", "workspace"]

  schema "assets" do
    field(:filename, :string)
    field(:content_type, :string)
    field(:size_bytes, :integer)
    field(:storage_key, :string)
    field(:asset_type, :string)
    field(:status, :string, default: "pending")

    # Polymorphic association - tracks which item the asset is attached to
    field(:attachable_type, :string)
    field(:attachable_id, Ecto.UUID)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)
    belongs_to(:uploaded_by, Missionspace.Accounts.User)

    timestamps()
  end

  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [
      :filename,
      :content_type,
      :size_bytes,
      :storage_key,
      :asset_type,
      :status,
      :workspace_id,
      :uploaded_by_id,
      :attachable_type,
      :attachable_id
    ])
    |> validate_required([
      :filename,
      :content_type,
      :size_bytes,
      :storage_key,
      :asset_type,
      :workspace_id,
      :uploaded_by_id,
      :attachable_type,
      :attachable_id
    ])
    |> validate_inclusion(:asset_type, @asset_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_attachable_type()
    |> validate_number(:size_bytes, greater_than: 0)
    |> unique_constraint(:storage_key)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:uploaded_by_id)
  end

  defp validate_attachable_type(changeset) do
    case get_field(changeset, :attachable_type) do
      nil -> changeset
      _type -> validate_inclusion(changeset, :attachable_type, @attachable_types)
    end
  end

  def status_changeset(asset, status) do
    asset
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @statuses)
  end

  def asset_types, do: @asset_types
  def statuses, do: @statuses
end
