# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :missionspace,
  ecto_repos: [Missionspace.Repo],
  generators: [timestamp_type: :utc_datetime_usec]

# Configure the endpoint
config :missionspace, MissionspaceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: MissionspaceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Missionspace.PubSub,
  live_view: [signing_salt: "RCwyDsWd"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :missionspace, Missionspace.Mailer, adapter: Swoosh.Adapters.Local

# Email sender and frontend URL
config :missionspace, :from_email, "noreply@missionspace.co"
config :missionspace, :frontend_url, "http://localhost:5173"
config :missionspace, :github_app_install_url, nil

config :missionspace, :github_app,
  app_id: nil,
  private_key_pem: nil,
  api_base_url: "https://api.github.com"

config :missionspace, :codex_oauth,
  auth_base_url: "https://auth.openai.com",
  client_id: "app_EMoamEEZ73f0CkXaXp7hrann",
  scope: "openid profile email offline_access api.connectors.read api.connectors.invoke",
  originator: "codex_cli_rs",
  callback_path: "/settings/automation",
  state_max_age_seconds: 15 * 60

config :missionspace, :sprite,
  api_base_url: nil,
  api_token: nil,
  org_slug: nil,
  execute_path: "/api/v1/agent-runs/execute",
  status_path_template: "/api/v1/agent-runs/:session_id",
  timeout_ms: 300_000,
  poll_interval_ms: 2_000,
  max_polls: 120

config :missionspace, Missionspace.Jido,
  max_tasks: 1_000,
  agent_pools: []

config :missionspace, Oban,
  repo: Missionspace.Repo,
  plugins: [{Oban.Plugins.Pruner, max_age: 60 * 60 * 24}],
  queues: [automation: 2]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
