defmodule Missionspace.Automation.TaskAgentAssignment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @providers ["codex"]
  @modes ["autonomous", "manual"]

  schema "task_agent_assignments" do
    field(:provider, :string, default: "codex")
    field(:mode, :string, default: "autonomous")
    field(:active, :boolean, default: true)
    field(:preferred_repositories, {:array, :string}, default: [])
    field(:instructions, :string)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)
    belongs_to(:task, Missionspace.Lists.Task)
    belongs_to(:assigned_by, Missionspace.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:provider, :mode, :active, :preferred_repositories, :instructions])
    |> validate_required([:provider, :mode, :active, :preferred_repositories])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:mode, @modes)
    |> validate_length(:instructions, max: 5_000)
  end
end
