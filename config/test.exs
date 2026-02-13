import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :meddie, Meddie.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "meddie_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :meddie, MeddieWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "zlcKYiNUUQDuIs5L6gxpWZbaqSEFDvqEsEAAYe/YOZVbZSxBtwkaf/pRGdT5TK0c",
  server: false

# In test we don't send emails
config :meddie, Meddie.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Oban inline testing
config :meddie, Oban, testing: :inline

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# File storage: local filesystem for testing
config :meddie, :storage_impl, Meddie.Storage.Local

# AI providers: mock for testing
config :meddie, :ai,
  parsing_provider: Meddie.AI.Providers.Mock,
  chat_provider: Meddie.AI.Providers.Mock

# Memory: mock embeddings for testing
config :meddie, :embeddings_impl, Meddie.Memory.Embeddings.Mock

# Disable Telegram polling in tests
config :meddie, :telegram, polling_enabled: false
