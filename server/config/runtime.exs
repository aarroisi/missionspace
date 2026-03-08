import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/missionspace start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :missionspace, MissionspaceWeb.Endpoint, server: true
end

# Resend email adapter (production)
if System.get_env("RESEND_API_KEY") do
  config :missionspace, Missionspace.Mailer,
    adapter: Swoosh.Adapters.Resend,
    api_key: System.get_env("RESEND_API_KEY")

  config :swoosh, :api_client, Swoosh.ApiClient.Req
end

if System.get_env("FROM_EMAIL") do
  config :missionspace, :from_email, System.get_env("FROM_EMAIL")
end

default_frontend_url =
  case config_env() do
    :prod -> "https://missionspace.co"
    _ -> "http://localhost:5173"
  end

frontend_url = System.get_env("FRONTEND_URL", default_frontend_url)

config :missionspace, :frontend_url, frontend_url

parse_boolean_env = fn env_name, default ->
  case System.get_env(env_name) do
    nil ->
      default

    value ->
      normalized_value =
        value
        |> String.trim()
        |> String.downcase()

      normalized_value in ["1", "true", "yes", "on"]
  end
end

parse_integer_env = fn env_name, default ->
  case System.get_env(env_name) do
    nil ->
      default

    value ->
      case Integer.parse(String.trim(value)) do
        {parsed, ""} when parsed > 0 -> parsed
        _ -> default
      end
  end
end

github_app_install_url =
  case System.get_env("GITHUB_APP_INSTALL_URL") do
    nil -> nil
    "" -> nil
    url -> String.trim(url)
  end

config :missionspace, :github_app_install_url, github_app_install_url

config :missionspace, :github_app,
  app_id: System.get_env("GITHUB_APP_ID"),
  private_key_pem: System.get_env("GITHUB_APP_PRIVATE_KEY_PEM"),
  api_base_url: System.get_env("GITHUB_API_BASE_URL", "https://api.github.com")

default_codex_oauth_scope =
  "openid profile email offline_access api.connectors.read api.connectors.invoke"

config :missionspace, :codex_oauth,
  auth_base_url: System.get_env("CODEX_OAUTH_BASE_URL", "https://auth.openai.com"),
  client_id: System.get_env("CODEX_OAUTH_CLIENT_ID", "app_EMoamEEZ73f0CkXaXp7hrann"),
  scope: System.get_env("CODEX_OAUTH_SCOPE", default_codex_oauth_scope),
  originator: System.get_env("CODEX_OAUTH_ORIGINATOR", "codex_cli_rs"),
  callback_path: System.get_env("CODEX_OAUTH_CALLBACK_PATH", "/settings/automation"),
  state_max_age_seconds: parse_integer_env.("CODEX_OAUTH_STATE_MAX_AGE_SECONDS", 15 * 60)

config :missionspace, :sprite,
  api_base_url: System.get_env("SPRITE_API_BASE_URL"),
  api_token: System.get_env("SPRITE_API_TOKEN"),
  org_slug: System.get_env("SPRITE_ORG_SLUG"),
  execute_path: System.get_env("SPRITE_EXECUTE_PATH", "/api/v1/agent-runs/execute"),
  status_path_template:
    System.get_env("SPRITE_STATUS_PATH_TEMPLATE", "/api/v1/agent-runs/:session_id"),
  timeout_ms: parse_integer_env.("SPRITE_TIMEOUT_MS", 300_000),
  poll_interval_ms: parse_integer_env.("SPRITE_POLL_INTERVAL_MS", 2_000),
  max_polls: parse_integer_env.("SPRITE_MAX_POLLS", 120)

automation_worker_enabled = parse_boolean_env.("AUTOMATION_WORKER_ENABLED", true)

automation_queue_limit = parse_integer_env.("AUTOMATION_MAX_CONCURRENCY", 2)

automation_queues =
  if automation_worker_enabled, do: [automation: automation_queue_limit], else: []

config :missionspace,
       Oban,
       Keyword.merge(Application.get_env(:missionspace, Oban, []),
         queues: automation_queues
       )

default_origins =
  if config_env() == :prod do
    [frontend_url, "https://missionspace.co", "https://www.missionspace.co"]
  else
    [frontend_url]
  end

origins =
  default_origins
  |> Enum.concat(
    case System.get_env("CORS_ORIGINS") do
      nil -> []
      cors -> String.split(cors, ",", trim: true)
    end
  )
  |> Enum.reject(&is_nil/1)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
  |> Enum.uniq()

if origins != [] do
  config :missionspace, :cors_origins, origins
  config :missionspace, MissionspaceWeb.Endpoint, check_origin: origins
end

config :missionspace, MissionspaceWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Web Push VAPID configuration
if System.get_env("VAPID_PUBLIC_KEY") do
  config :web_push_encryption, :vapid_details,
    subject: System.get_env("VAPID_SUBJECT", "mailto:support@missionspace.co"),
    public_key: System.get_env("VAPID_PUBLIC_KEY"),
    private_key: System.get_env("VAPID_PRIVATE_KEY")
end

# Cloudflare R2 Storage Configuration
# R2 uses S3-compatible API with presigned URLs for all access
if System.get_env("R2_ACCESS_KEY_ID") do
  config :missionspace, :r2,
    access_key_id: System.get_env("R2_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY"),
    bucket: System.get_env("R2_BUCKET"),
    host: System.get_env("R2_HOST"),
    region: System.get_env("R2_REGION", "auto")

  config :ex_aws,
    access_key_id: System.get_env("R2_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("R2_SECRET_ACCESS_KEY"),
    region: System.get_env("R2_REGION", "auto")

  config :ex_aws, :s3,
    scheme: "https://",
    host: System.get_env("R2_HOST"),
    region: System.get_env("R2_REGION", "auto")
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :missionspace, Missionspace.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :missionspace, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :missionspace, MissionspaceWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :missionspace, MissionspaceWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :missionspace, MissionspaceWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :missionspace, Missionspace.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
