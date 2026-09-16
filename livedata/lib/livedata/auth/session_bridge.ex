defmodule Livedata.Auth.SessionBridge do
  @moduledoc """
  Short-lived ETS-backed token bridge for transferring an authenticated user
  identity from a LiveView process into a Plug session cookie.

  A login LiveView stores the identity here after a successful Cognito auth,
  then navigates to the session bridge route in AuthController, which reads
  and consumes the token to write the Plug session.

  Tokens expire after 30 seconds and are single-use.
  """

  use GenServer

  @table :auth_session_bridge
  @ttl_seconds 30

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @spec store(map()) :: String.t()
  def store(user_identity) when is_map(user_identity) do
    token = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    expires_at = System.system_time(:second) + @ttl_seconds
    :ets.insert(@table, {token, user_identity, expires_at})
    token
  end

  @spec fetch(String.t()) :: {:ok, map()} | {:error, :not_found}
  def fetch(token) do
    now = System.system_time(:second)

    case :ets.lookup(@table, token) do
      [{^token, user_identity, expires_at}] when expires_at > now ->
        :ets.delete(@table, token)
        {:ok, user_identity}

      _ ->
        {:error, :not_found}
    end
  end

  @impl GenServer
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:cleanup, state) do
    now = System.system_time(:second)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, :timer.minutes(1))
end
