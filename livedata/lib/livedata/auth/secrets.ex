defmodule Livedata.Auth.Secrets do
  @moduledoc """
  Loads Cognito configuration from AWS SSM and Secrets Manager.

  All values are cached in Application env after the first successful fetch.
  In dev and test the config keys may be set directly, bypassing remote calls —
  set `cognito_credentials` or `cognito_pool_config` in the relevant config file.

  @req: KR 8.3
  """

  @cache_key :cognito_credentials
  @pool_cache_key :cognito_pool_config

  @type credentials :: %{client_id: String.t(), client_secret: String.t()}
  @type pool_config :: %{region: String.t(), user_pool_id: String.t()}

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

  @spec cognito_pool_config() :: {:ok, pool_config()} | {:error, term()}
  def cognito_pool_config do
    case Application.get_env(:livedata, @pool_cache_key) do
      nil -> fetch_and_cache_pool_config()
      cached -> {:ok, cached}
    end
  end

  defp fetch_and_cache_pool_config do
    with {:ok, region} <- fetch_ssm_parameter("/a2t-mrv/cognito/region"),
         {:ok, user_pool_id} <- fetch_ssm_parameter("/a2t-mrv/cognito/user-pool-id") do
      config = %{region: region, user_pool_id: user_pool_id}
      Application.put_env(:livedata, @pool_cache_key, config)
      {:ok, config}
    end
  end

  defp fetch_ssm_parameter(name) do
    operation = %ExAws.Operation.JSON{
      http_method: :post,
      service: :ssm,
      headers: [
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-target", "AmazonSSM.GetParameter"}
      ],
      data: %{"Name" => name, "WithDecryption" => false},
      path: "/"
    }

    case ExAws.request(operation) do
      {:ok, %{"Parameter" => %{"Value" => value}}} -> {:ok, value}
      {:ok, _} -> {:error, :missing_ssm_parameter}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_secret(secret_name) do
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
