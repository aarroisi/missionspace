defmodule Bridge.Lists.List do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "lists" do
    field(:name, :string)
    field(:prefix, :string)
    field(:task_sequence_counter, :integer, default: 0)
    field(:visibility, :string, default: "shared")
    field(:starred, :boolean, virtual: true, default: false)

    belongs_to(:workspace, Bridge.Accounts.Workspace)
    belongs_to(:created_by, Bridge.Accounts.User)
    has_many(:statuses, Bridge.Lists.ListStatus)
    has_many(:tasks, Bridge.Lists.Task)

    timestamps()
  end

  @doc "Changeset for creating a new list (accepts prefix)."
  def create_changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :prefix, :workspace_id, :created_by_id, :visibility])
    |> validate_required([:name, :prefix, :workspace_id])
    |> validate_inclusion(:visibility, ["private", "shared"])
    |> validate_format(:prefix, ~r/^[A-Z]{2,5}$/, message: "must be 2-5 uppercase letters")
    |> unique_constraint(:prefix,
      name: :lists_workspace_id_prefix_index,
      message: "this prefix is already used by another board"
    )
  end

  @doc "Changeset for updating a list (prefix is immutable)."
  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :workspace_id, :created_by_id, :visibility])
    |> validate_required([:name, :workspace_id])
    |> validate_inclusion(:visibility, ["private", "shared"])
  end
end
