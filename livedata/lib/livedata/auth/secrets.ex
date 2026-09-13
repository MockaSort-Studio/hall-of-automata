defmodule Livedata.Auth.Secrets do
  @moduledoc """
  Loads Cognito client credentials from AWS Secrets Manager.

  Credentials are cached in Application env after the first successful fetch.
  In dev and test the config key `:cognito_credentials` may be set directly,
  bypassing the remote call entirely — set `COGNITO_CLIENT_ID` env var in dev,
  or set `cognito_credentials` in `config/test.exs`.
  """

  @cache_key :cognito_credentials

  @type credentials :: %{client_id: String.t(), client_secret: String.t()}

  @spec client_credentials() :: {:ok, credentials()} | {:error, term()}
  def client_credentials do
    case Application.get_env(:livedata, @cache_key) do
      nil -> fetch_and_cache()
      cached -> {:ok, cached}
    end
  end

  defp fetch_and_cache do
    secret_name = Application.fetch_env!(:livedata, :cognito_secret_name)

    with {:ok, json} <- fetch_secret(secret_name),
         {:ok, raw} <- Jason.decode(json) do
      credentials = %{client_id: raw["client_id"], client_secret: raw["client_secret"]}
      Application.put_env(:livedata, @cache_key, credentials)
      {:ok, credentials}
    end
  end

  defp fetch_secret(secret_name) do
    # Raw Secrets Manager API call via ex_aws core.
    # ExAws resolves the endpoint from :secretsmanager service and region config.
    operation = %ExAws.Operation.JSON{
      http_method: :post,
      service: :secretsmanager,
      headers: [
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-target", "secretsmanager.GetSecretValue"}
      ],
      data: %{"SecretId" => secret_name},
      path: "/"
    }

    case ExAws.request(operation) do
      {:ok, %{"SecretString" => value}} -> {:ok, value}
      {:ok, _} -> {:error, :missing_secret_string}
      {:error, reason} -> {:error, reason}
    end
  end
end
