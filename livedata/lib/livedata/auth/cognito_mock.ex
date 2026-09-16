defmodule Livedata.Auth.CognitoMock do
  @moduledoc """
  Offline Cognito implementation for dev, test, and Render preview environments.

  Accepts any username paired with the configured `:auth_bypass_password`. Returns
  a synthetic user identity — no network calls, no Cognito user pool required.

  @req: KR 8.3
  """

  @behaviour Livedata.Auth.ProviderBehaviour

  @impl true
  def authenticate(_username, password) do
    expected = Application.get_env(:livedata, :auth_bypass_password)

    cond do
      is_nil(expected) ->
        {:error, :bypass_password_not_configured}

      password == expected ->
        {:ok, synthetic_user()}

      true ->
        {:error, :invalid_credentials}
    end
  end

  @impl true
  def refresh_token(_username, _refresh_token) do
    {:ok, synthetic_user()}
  end

  defp synthetic_user do
    %{
      "sub" => "mock-sub-dev",
      "email" => "dev@mock.local",
      "name" => "Dev User",
      "cognito_username" => "dev",
      "exp" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix(),
      "refresh_token" => "mock_refresh_token",
      "is_admin" => false
    }
  end
end
