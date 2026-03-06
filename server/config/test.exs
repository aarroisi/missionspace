import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :missionspace, Missionspace.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "missionspace_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :missionspace, MissionspaceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "MhfT3yrDwylbkz8YPjU3As+gwE99yMryhcMob+uxFsKXAxdW/BAmJkb9h4GT4pRp",
  server: false

# In test we don't send emails
config :missionspace, Missionspace.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Mock R2 storage configuration for tests
config :missionspace, :r2,
  access_key_id: "test_access_key",
  secret_access_key: "test_secret_key",
  bucket: "test-bucket",
  host: "test.r2.cloudflarestorage.com",
  region: "auto",
  public_url: "https://test-bucket.example.com"

# Use mock storage in tests
config :missionspace, :storage_adapter, :mock
