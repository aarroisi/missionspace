defmodule Missionspace.Automation.AgentRunEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @levels ["debug", "info", "warning", "error"]

  schema "agent_run_events" do
    field(:event_type, :string)
    field(:level, :string, default: "info")
    field(:message, :string)
    field(:payload, :map, default: %{})
    field(:occurred_at, :utc_datetime_usec)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)
    belongs_to(:agent_run, Missionspace.Automation.AgentRun)

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :level, :message, :payload, :occurred_at])
    |> validate_required([:event_type, :level, :payload, :occurred_at])
    |> validate_inclusion(:level, @levels)
  end
end
