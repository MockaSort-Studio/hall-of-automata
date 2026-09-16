defmodule Livedata.Auth.Provider do
  @moduledoc """
  Entry point for all authentication operations.

  Delegates to the configured backend module (`:auth_provider` application
  config key). In production this is `Livedata.Auth.Cognito`; in dev/test
  it is `Livedata.Auth.CognitoMock`. Callers never reference Cognito directly.

  @req: KR 8.3
  """

  @spec authenticate(String.t(), String.t()) ::
          {:ok, Livedata.Auth.ProviderBehaviour.user_identity()} | {:error, term()}
  def authenticate(username, password) do
    backend().authenticate(username, password)
  end

  @spec refresh_token(String.t(), String.t()) ::
          {:ok, Livedata.Auth.ProviderBehaviour.user_identity()} | {:error, term()}
  def refresh_token(username, refresh_token) do
    backend().refresh_token(username, refresh_token)
  end

  defp backend do
    Application.get_env(:livedata, :auth_provider, Livedata.Auth.Cognito)
  end
end
