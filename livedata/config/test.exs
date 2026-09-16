import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :livedata, Livedata.Repo,
  socket_dir: System.get_env("PGHOST") || "/tmp",
  port: String.to_integer(System.get_env("PGPORT") || "5433"),
  username: System.get_env("USER") || "postgres",
  database: "livedata_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :livedata, LivedataWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3CItBLOs86ti815xwDfBkzlLg+JbzOIECMnP0leuv+yh/bMqtjlqM2H7JkBhZyad",
  server: true

config :livedata, :sql_sandbox, true

config :wallaby,
  otp_app: :livedata,
  driver: Wallaby.Chrome,
  chromedriver: [headless: true, binary: System.get_env("CHROME_BINARY")],
  base_url: "http://localhost:4002"

# In test we don't send emails
config :livedata, Livedata.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

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

# Auth — test uses CognitoMock with a fixed bypass password.
config :livedata,
  auth_provider: Livedata.Auth.CognitoMock,
  auth_bypass_password: "test_bypass_password",
  cognito_issuer_url: "https://cognito-idp.eu-west-1.amazonaws.com/test-pool",
  cognito_secret_name: "a2t-mrv/cognito/client-secret",
  cognito_credentials: %{client_id: "test_client_id", client_secret: "test_secret"},
  cognito_req_opts: [plug: {Req.Test, Livedata.Auth.Cognito}]

# Fake AWS credentials so ExAws.Auth.headers/6 can sign requests in tests.
config :ex_aws,
  access_key_id: "test_access_key",
  secret_access_key: "test_secret_key",
  region: "eu-north-1"
