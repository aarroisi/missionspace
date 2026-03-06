defmodule Missionspace.Namespaces.Prefix do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_entity_types ["list", "doc_folder"]

  schema "prefixes" do
    field(:prefix, :string)
    field(:entity_type, :string)
    field(:entity_id, Ecto.UUID)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)

    timestamps()
  end

  @doc false
  def changeset(prefix_record, attrs) do
    prefix_record
    |> cast(attrs, [:prefix, :entity_type, :entity_id, :workspace_id])
    |> validate_required([:prefix, :entity_type, :entity_id, :workspace_id])
    |> validate_format(:prefix, ~r/^[A-Z]{2,5}$/, message: "must be 2-5 uppercase letters")
    |> validate_inclusion(:entity_type, @valid_entity_types)
    |> unique_constraint([:workspace_id, :prefix],
      name: :prefixes_workspace_id_prefix_index,
      message: "this prefix is already in use"
    )
  end
end
