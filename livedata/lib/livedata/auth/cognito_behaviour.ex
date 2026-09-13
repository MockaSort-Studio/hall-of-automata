defmodule Livedata.Auth.CognitoBehaviour do
  @moduledoc """
  Behaviour for the Cognito OIDC client — enables Mox-based testing.
  """

  @callback authorize_url() ::
              {:ok, url :: String.t(), session_params :: map()} | {:error, term()}

  @callback exchange_code(params :: map(), session_params :: map()) ::
              {:ok, user :: map(), token :: map()} | {:error, term()}
end
