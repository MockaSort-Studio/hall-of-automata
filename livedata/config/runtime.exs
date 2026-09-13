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
  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  db_repo_config =
    case System.get_env("DB_SECRET_ARN") do
      arn when is_binary(arn) and arn != "" ->
        # RDS deployment: credentials live in Secrets Manager, never in env files.
        # DB_SECRET_ARN holds only the ARN (a resource identifier, not a credential).
        # The EC2 instance profile grants secretsmanager:GetSecretValue on this ARN.
        db_config = Livedata.SecretsManager.fetch_db_config!(arn)

        Keyword.merge(db_config,
          ssl: true,
          pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
          socket_options: maybe_ipv6
        )

      _ ->
        # Fallback: DATABASE_URL_* for non-RDS deployments (Neon / local Docker).
        # Blank counts as unset — `System.get_env/1` returns "" for empty vars.
        database_url =
          Enum.find_value(~w(DATABASE_URL_PR DATABASE_URL_MAIN DATABASE_URL), fn var ->
            case System.get_env(var) do
              nil -> nil
              "" -> nil
              value -> value
            end
          end) ||
            raise """
            Neither DB_SECRET_ARN nor a DATABASE_URL_* variable is set.
            For RDS: set DB_SECRET_ARN to the Secrets Manager ARN from `terraform output db_secret_arn`.
            For Neon/local: set DATABASE_URL_MAIN to the connection string.
            """

        # DATABASE_SSL: default "true" (verify-peer). Set to "false" only for a
        # self-hosted Postgres without TLS (e.g. deploy/compose.yml). Never
        # "false" in production against a remote database.
        database_ssl = System.get_env("DATABASE_SSL", "true") != "false"

        [
          ssl: database_ssl,
          url: database_url,
          pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
          socket_options: maybe_ipv6
        ]
    end

  config :livedata, Livedata.Repo, db_repo_config

  # SECRET_KEY_BASE: fetched from Secrets Manager on RDS deployments.
  # SECRET_KEY_BASE_SECRET_ARN holds the ARN (not the key itself).
  secret_key_base =
    case System.get_env("SECRET_KEY_BASE_SECRET_ARN") do
      arn when is_binary(arn) and arn != "" ->
        Livedata.SecretsManager.fetch_string!(arn)

      _ ->
        System.get_env("SECRET_KEY_BASE") ||
          raise """
          Neither SECRET_KEY_BASE_SECRET_ARN nor SECRET_KEY_BASE is set.
          For RDS: set SECRET_KEY_BASE_SECRET_ARN to the ARN from `terraform output secret_key_base_secret_arn`.
          For Neon/local: set SECRET_KEY_BASE (generate with: mix phx.gen.secret).
          """
    end

  host = System.get_env("PHX_HOST") || "example.com"

  config :livedata, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :livedata, LivedataWeb.Endpoint,
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
  #     config :livedata, LivedataWeb.Endpoint,
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
  #     config :livedata, LivedataWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :livedata, Livedata.Mailer,
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
