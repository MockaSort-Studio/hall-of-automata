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
#     PHX_SERVER=true bin/livedata start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :livedata, LivedataWeb.Endpoint, server: true
end

# Only override the port at runtime for non-test envs — test.exs binds 4002 and
# runtime.exs must not clobber it (otherwise `server: true` under Wallaby would
# bind 4000 and collide with any running `mix phx.server`).
if config_env() != :test do
  config :livedata, LivedataWeb.Endpoint,
    http: [port: String.to_integer(System.get_env("PORT", "4000"))]
end

if config_env() == :prod do
  # DB credentials, Repo config, and secret_key_base are resolved by
  # Livedata.SecretsProvider (registered in mix.exs releases config_providers).
  # It fetches from Secrets Manager (EC2/DB_SECRET_ARN) or reads DATABASE_URL_*
  # env vars (Neon/Docker). runtime.exs is kept free of credential fetching.

  host = System.get_env("PHX_HOST") || "example.com"

  config :livedata, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :ex_aws, region: System.get_env("AWS_DEFAULT_REGION", "eu-north-1")

  config :livedata, LivedataWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ]

  # Auth: when AUTH_BYPASS_PASSWORD is set, use CognitoMock (Render preview).
  # Otherwise use real Cognito — region and user pool ID are fetched from SSM at
  # first auth attempt. ExAws region is set above from AWS_DEFAULT_REGION.
  if bypass_password = System.get_env("AUTH_BYPASS_PASSWORD") do
    config :livedata,
      auth_provider: Livedata.Auth.CognitoMock,
      auth_bypass_password: bypass_password
  else
    config :livedata,
      auth_provider: Livedata.Auth.Cognito,
      cognito_secret_name: System.get_env("COGNITO_SECRET_NAME", "a2t-mrv/cognito/client-secret")
  end
end
