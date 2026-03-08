defmodule Missionspace.Automation.AgentRun do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @providers ["codex"]
  @statuses ["queued", "running", "succeeded", "failed", "cancelled"]

  schema "agent_runs" do
    field(:provider, :string, default: "codex")
    field(:status, :string, default: "queued")
    field(:run_goal, :string)
    field(:selected_repositories, {:array, :string}, default: [])
    field(:sprite_session_id, :string)
    field(:pull_request_urls, {:array, :string}, default: [])
    field(:summary, :string)
    field(:error_message, :string)
    field(:started_at, :utc_datetime_usec)
    field(:completed_at, :utc_datetime_usec)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)
    belongs_to(:task, Missionspace.Lists.Task)
    belongs_to(:task_agent_assignment, Missionspace.Automation.TaskAgentAssignment)
    belongs_to(:initiated_by, Missionspace.Accounts.User)

    has_many(:events, Missionspace.Automation.AgentRunEvent)

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :provider,
      :status,
      :run_goal,
      :selected_repositories,
      :sprite_session_id,
      :pull_request_urls,
      :summary,
      :error_message,
      :started_at,
      :completed_at
    ])
    |> validate_required([:provider, :status, :selected_repositories, :pull_request_urls])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:status, @statuses)
  end
end
