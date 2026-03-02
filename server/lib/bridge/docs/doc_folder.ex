defmodule Bridge.Docs.DocFolder do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  schema "doc_folders" do
    field(:name, :string)
    field(:prefix, :string)
    field(:doc_sequence_counter, :integer, default: 0)
    field(:visibility, :string, default: "shared")
    field(:starred, :boolean, virtual: true, default: false)

    belongs_to(:workspace, Bridge.Accounts.Workspace)
    belongs_to(:created_by, Bridge.Accounts.User)
    has_many(:docs, Bridge.Docs.Doc)

    timestamps()
  end

  @doc "Changeset for creating a new doc folder (accepts prefix)."
  def create_changeset(doc_folder, attrs) do
    doc_folder
    |> cast(attrs, [:name, :prefix, :workspace_id, :created_by_id, :visibility])
    |> validate_required([:name, :prefix, :workspace_id])
    |> validate_inclusion(:visibility, ["private", "shared"])
    |> validate_format(:prefix, ~r/^[A-Z]{2,5}$/, message: "must be 2-5 uppercase letters")
    |> unique_constraint(:prefix,
      name: :doc_folders_workspace_id_prefix_index,
      message: "this prefix is already used by another doc folder"
    )
  end

  @doc "Changeset for updating a doc folder (prefix is immutable)."
  def changeset(doc_folder, attrs) do
    doc_folder
    |> cast(attrs, [:name, :visibility])
    |> validate_required([:name])
    |> validate_inclusion(:visibility, ["private", "shared"])
  end
end
