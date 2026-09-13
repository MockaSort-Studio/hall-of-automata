defmodule Livedata.Auth.Cognito do
  @moduledoc """
  OIDC authorization_code flow against the Cognito Hosted UI via `assent`.

  Wraps `Assent.Strategy.OIDC` with the runtime config (issuer URL, redirect
  URI, client credentials) assembled at call time from Application env and
  the Secrets module.
  """

  @behaviour Livedata.Auth.CognitoBehaviour

  alias Livedata.Auth.Secrets

  @strategy Assent.Strategy.OIDC

  @impl true
  def authorize_url do
    with {:ok, creds} <- Secrets.client_credentials(),
         {:ok, config} <- build_config(creds),
         {:ok, %{url: url, session_params: session_params}} <- @strategy.authorize_url(config) do
      {:ok, url, session_params}
    end
  end

  @impl true
  def exchange_code(params, session_params) do
    with {:ok, creds} <- Secrets.client_credentials(),
         {:ok, config} <- build_config(creds),
         {:ok, %{user: user, token: token}} <- @strategy.callback(config, params, session_params) do
      {:ok, user, token}
    end
  end

  defp build_config(creds) do
    with {:ok, issuer_url} <- Application.fetch_env(:livedata, :cognito_issuer_url),
         {:ok, redirect_uri} <- Application.fetch_env(:livedata, :cognito_redirect_uri) do
      http_adapter =
        Application.get_env(:livedata, :assent_http_adapter, {Assent.HTTPAdapter.Req, []})

      {:ok,
       [
         client_id: creds.client_id,
         client_secret: creds.client_secret,
         base_url: issuer_url,
         redirect_uri: redirect_uri,
         authorization_params: [scope: "openid email profile"],
         http_adapter: http_adapter
       ]}
    else
      :error -> {:error, :cognito_not_configured}
    end
  end
end
