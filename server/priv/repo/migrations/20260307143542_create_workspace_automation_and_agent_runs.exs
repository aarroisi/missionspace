defmodule Missionspace.Repo.Migrations.CreateWorkspaceAutomationAndAgentRuns do
  use Ecto.Migration

  def change do
    create table(:workspace_automation_settings, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:provider, :string, null: false, default: "codex")
      add(:sprite_base_url, :string, null: false, default: "https://sprites.dev")
      add(:sprite_org_slug, :string)
      add(:github_app_installation_id, :string)
      add(:default_base_branch, :string, null: false, default: "main")
      add(:autonomous_execution_enabled, :boolean, null: false, default: false)
      add(:auto_open_prs, :boolean, null: false, default: true)

      add(:codex_api_key_ciphertext, :text)
      add(:codex_api_key_last4, :string)
      add(:codex_api_key_updated_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:workspace_automation_settings, [:workspace_id]))
    create(index(:workspace_automation_settings, [:provider]))

    create table(:workspace_automation_repositories, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:provider, :string, null: false, default: "github")
      add(:repo_owner, :string, null: false)
      add(:repo_name, :string, null: false)
      add(:default_branch, :string, null: false, default: "main")
      add(:enabled, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:workspace_automation_repositories, [:workspace_id]))

    create(
      unique_index(
        :workspace_automation_repositories,
        [:workspace_id, :provider, :repo_owner, :repo_name],
        name: :workspace_automation_repositories_unique_repo_index
      )
    )

    create table(:task_agent_assignments, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false)

      add(:assigned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false
      )

      add(:provider, :string, null: false, default: "codex")
      add(:mode, :string, null: false, default: "autonomous")
      add(:active, :boolean, null: false, default: true)
      add(:preferred_repositories, {:array, :string}, null: false, default: [])
      add(:instructions, :text)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:task_agent_assignments, [:workspace_id]))
    create(index(:task_agent_assignments, [:task_id]))
    create(index(:task_agent_assignments, [:active]))

    create(
      unique_index(:task_agent_assignments, [:task_id],
        where: "active = true",
        name: :task_agent_assignments_active_task_unique_index
      )
    )

    create table(:agent_runs, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false)

      add(
        :task_agent_assignment_id,
        references(:task_agent_assignments, type: :binary_id, on_delete: :nilify_all)
      )

      add(:initiated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false
      )

      add(:provider, :string, null: false, default: "codex")
      add(:status, :string, null: false, default: "queued")
      add(:run_goal, :text)
      add(:selected_repositories, {:array, :string}, null: false, default: [])
      add(:sprite_session_id, :string)
      add(:pull_request_urls, {:array, :string}, null: false, default: [])
      add(:summary, :text)
      add(:error_message, :text)
      add(:started_at, :utc_datetime_usec)
      add(:completed_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:agent_runs, [:workspace_id]))
    create(index(:agent_runs, [:task_id]))
    create(index(:agent_runs, [:status]))
    create(index(:agent_runs, [:inserted_at]))

    create table(:agent_run_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:agent_run_id, references(:agent_runs, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:event_type, :string, null: false)
      add(:level, :string, null: false, default: "info")
      add(:message, :text)
      add(:payload, :map, null: false, default: %{})
      add(:occurred_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:agent_run_events, [:workspace_id]))
    create(index(:agent_run_events, [:agent_run_id]))
    create(index(:agent_run_events, [:occurred_at]))

    create(
      constraint(:task_agent_assignments, :task_agent_assignments_mode_check,
        check: "mode IN ('autonomous', 'manual')"
      )
    )

    create(
      constraint(:agent_runs, :agent_runs_status_check,
        check: "status IN ('queued', 'running', 'succeeded', 'failed', 'cancelled')"
      )
    )

    create(
      constraint(:agent_run_events, :agent_run_events_level_check,
        check: "level IN ('debug', 'info', 'warning', 'error')"
      )
    )
  end
end
