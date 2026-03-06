defmodule Missionspace.Projects.ProjectItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias Missionspace.Projects.Project

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_item_types ["list", "doc_folder", "channel"]

  schema "project_items" do
    field(:item_type, :string)
    field(:item_id, :binary_id)

    belongs_to(:project, Project)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(project_item, attrs) do
    project_item
    |> cast(attrs, [:project_id, :item_type, :item_id])
    |> validate_required([:project_id, :item_type, :item_id])
    |> validate_inclusion(:item_type, @valid_item_types)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint([:item_type, :item_id], message: "item already belongs to a project")
  end
end
