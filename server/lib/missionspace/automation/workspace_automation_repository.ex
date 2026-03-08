defmodule Missionspace.Automation.WorkspaceAutomationRepository do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @providers ["github"]

  schema "workspace_automation_repositories" do
    field(:provider, :string, default: "github")
    field(:repo_owner, :string)
    field(:repo_name, :string)
    field(:default_branch, :string, default: "main")
    field(:enabled, :boolean, default: true)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)

    timestamps()
  end

  @doc false
  def changeset(repository, attrs) do
    repository
    |> cast(attrs, [:provider, :repo_owner, :repo_name, :default_branch, :enabled])
    |> validate_required([:provider, :repo_owner, :repo_name, :default_branch, :enabled])
    |> validate_inclusion(:provider, @providers)
    |> validate_length(:repo_owner, min: 1, max: 255)
    |> validate_length(:repo_name, min: 1, max: 255)
    |> validate_length(:default_branch, min: 1, max: 100)
    |> unique_constraint([:workspace_id, :provider, :repo_owner, :repo_name],
      name: :workspace_automation_repositories_unique_repo_index
    )
  end
end
