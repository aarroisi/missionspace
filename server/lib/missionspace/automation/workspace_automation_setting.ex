defmodule Missionspace.Automation.WorkspaceAutomationSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @providers ["codex"]
  @codex_auth_methods ["api_key", "chatgpt_oauth"]

  schema "workspace_automation_settings" do
    field(:provider, :string, default: "codex")
    field(:sprite_base_url, :string, default: "https://sprites.dev")
    field(:sprite_org_slug, :string)
    field(:github_app_installation_id, :string)
    field(:default_base_branch, :string, default: "main")
    field(:autonomous_execution_enabled, :boolean, default: false)
    field(:auto_open_prs, :boolean, default: true)
    field(:codex_api_key_ciphertext, :string)
    field(:codex_api_key_last4, :string)
    field(:codex_api_key_updated_at, :utc_datetime_usec)

    field(:codex_auth_method, :string)
    field(:codex_oauth_account_id, :string)
    field(:codex_oauth_plan_type, :string)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)

    has_many(:repositories, Missionspace.Automation.WorkspaceAutomationRepository,
      foreign_key: :workspace_id,
      references: :workspace_id
    )

    timestamps()
  end

  @doc false
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [
      :provider,
      :sprite_base_url,
      :sprite_org_slug,
      :github_app_installation_id,
      :default_base_branch,
      :autonomous_execution_enabled,
      :auto_open_prs,
      :codex_api_key_ciphertext,
      :codex_api_key_last4,
      :codex_api_key_updated_at,
      :codex_auth_method,
      :codex_oauth_account_id,
      :codex_oauth_plan_type
    ])
    |> validate_required([
      :provider,
      :sprite_base_url,
      :default_base_branch,
      :autonomous_execution_enabled,
      :auto_open_prs
    ])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:codex_auth_method, @codex_auth_methods)
    |> validate_length(:default_base_branch, min: 1, max: 100)
    |> validate_length(:sprite_base_url, min: 1, max: 500)
    |> unique_constraint(:workspace_id)
  end
end
