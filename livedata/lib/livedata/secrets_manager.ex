defmodule Livedata.SecretsManager do
  @moduledoc """
  Fetches secrets from AWS Secrets Manager at runtime.

  Used in config/runtime.exs to retrieve DB credentials and SECRET_KEY_BASE
  from Secrets Manager using the EC2 instance profile for authorization.
  No credentials are stored in env files or committed config.
  """

  @doc """
  Fetches the RDS master user credential secret and returns an Ecto Repo config
  keyword list (hostname, port, username, password, database).

  The RDS-managed secret JSON has the fields: username, password, host, port, dbname.
  """
  def fetch_db_config!(secret_arn) do
    secret_arn
    |> fetch_raw!()
    |> parse_rds_secret!()
  end

  @doc """
  Fetches a plain-string secret value. Used for SECRET_KEY_BASE.
  """
  def fetch_string!(secret_arn) do
    fetch_raw!(secret_arn)
  end

  @doc """
  Parses the JSON payload from an RDS-managed credential secret into an
  Ecto Repo config keyword list.

  Exposed as a public function for unit-testability.
  """
  def parse_rds_secret!(json) do
    case Jason.decode(json) do
      {:ok,
       %{"username" => user, "password" => pass, "host" => host, "port" => port, "dbname" => db}} ->
        [hostname: host, port: port, username: user, password: pass, database: db]

      {:ok, _} ->
        raise "RDS secret missing expected fields (username, password, host, port, dbname)"

      {:error, reason} ->
        raise "Failed to parse RDS secret JSON: #{inspect(reason)}"
    end
  end

  defp fetch_raw!(secret_arn) do
    case ExAws.SecretsManager.get_secret_value(secret_arn) |> ExAws.request() do
      {:ok, %{"SecretString" => value}} ->
        value

      {:ok, _response} ->
        raise "Secret #{inspect(secret_arn)} has no SecretString (binary secrets are not supported)"

      {:error, reason} ->
        raise "Failed to fetch secret #{inspect(secret_arn)} from Secrets Manager: #{inspect(reason)}"
    end
  end
end
