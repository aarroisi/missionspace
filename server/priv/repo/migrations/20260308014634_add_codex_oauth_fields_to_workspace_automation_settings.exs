defmodule Missionspace.Repo.Migrations.AddCodexOauthFieldsToWorkspaceAutomationSettings do
  use Ecto.Migration

  def change do
    alter table(:workspace_automation_settings) do
      add(:codex_auth_method, :string)
      add(:codex_oauth_account_id, :string)
      add(:codex_oauth_plan_type, :string)
    end

    create(
      constraint(:workspace_automation_settings, :workspace_automation_settings_codex_auth_method,
        check: "codex_auth_method IS NULL OR codex_auth_method IN ('api_key', 'chatgpt_oauth')"
      )
    )
  end
end
