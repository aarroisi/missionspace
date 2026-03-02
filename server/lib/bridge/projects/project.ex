defmodule Bridge.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "projects" do
    field(:name, :string)
    field(:description, :string)
    field(:starred, :boolean, virtual: true, default: false)
    field(:start_date, :date)
    field(:end_date, :date)

    belongs_to(:workspace, Bridge.Accounts.Workspace)
    belongs_to(:created_by, Bridge.Accounts.User)
    has_many(:project_items, Bridge.Projects.ProjectItem)
    has_many(:project_members, Bridge.Projects.ProjectMember)
    has_many(:members, through: [:project_members, :user])

    timestamps()
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :name,
      :description,
      :start_date,
      :end_date,
      :workspace_id,
      :created_by_id
    ])
    |> validate_required([:name, :workspace_id])
    |> validate_dates()
  end

  defp validate_dates(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && Date.compare(start_date, end_date) == :gt do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
  end
end
