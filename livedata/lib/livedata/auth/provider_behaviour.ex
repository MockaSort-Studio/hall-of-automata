defmodule Livedata.Auth.ProviderBehaviour do
  @moduledoc """
  Behaviour contract for authentication backends.

  Backends implement this and are registered under the `:auth_provider`
  application config key. Callers use `Livedata.Auth.Provider` and never
  reference a specific backend module.

  @req: KR 8.3
  """

  @type user_identity :: %{String.t() => String.t() | integer() | nil}

  @callback authenticate(username :: String.t(), password :: String.t()) ::
              {:ok, user_identity()} | {:error, term()}

  @callback refresh_token(username :: String.t(), refresh_token :: String.t()) ::
              {:ok, user_identity()} | {:error, term()}
end
