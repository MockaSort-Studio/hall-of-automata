defmodule Livedata.SecretsProvider do
  @moduledoc """
  Config.Provider that assembles DB and Endpoint config from environment variables.

  The deploy script (scripts/deploy/after_install.sh) fetches credentials from
  AWS Secrets Manager using the AWS CLI and writes them to /etc/livedata/env
  before the application starts. This provider reads those variables and
  composes them into Ecto Repo config and LivedataWeb.Endpoint config.

  Three paths, resolved in order:

    1. EC2 deployment — after_install.sh fetches credentials and writes
       DATABASE_URL_MAIN and SECRET_KEY_BASE to /etc/livedata/env. This
       provider reads them as environment variables.

    2. Neon / Docker — DATABASE_URL_* or DATABASE_URL env vars set directly.

    3. Local dev (mix run) — this provider never executes; Config.Provider runs
       only in releases. dev.exs and env vars handle everything.

  runtime.exs owns non-secret prod config (endpoint URL, Cognito params, etc.)
  and is kept free of any credential fetching or external calls.
  """

  @behaviour Config.Provider

  @impl Config.Provider
  def init(opts), do: opts

  @impl Config.Provider
  def load(config, _opts) do
    patches =
      if(repo_opts = resolve_db(), do: [{Livedata.Repo, repo_opts}], else: []) ++
        case System.get_env("SECRET_KEY_BASE") do
          nil -> []
          skb -> [{LivedataWeb.Endpoint, [secret_key_base: skb]}]
        end

    if patches == [] do
      config
    else
      Config.Reader.merge(config, livedata: patches)
    end
  end

  defp resolve_db do
    case database_url() do
      nil ->
        nil

      url ->
        ssl =
          case System.get_env("DATABASE_SSL_CACERTFILE") do
            nil -> System.get_env("DATABASE_SSL", "true") != "false"
            ca -> [verify: :verify_peer, cacertfile: ca]
          end

        [url: url, ssl: ssl, pool_size: pool_size(), socket_options: ipv6_opts()]
    end
  end

  defp database_url do
    Enum.find_value(~w(DATABASE_URL_PR DATABASE_URL_MAIN DATABASE_URL), fn var ->
      case System.get_env(var) do
        nil -> nil
        "" -> nil
        v -> v
      end
    end)
  end

  defp pool_size, do: String.to_integer(System.get_env("POOL_SIZE", "10"))

  defp ipv6_opts, do: if(System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: [])
end
