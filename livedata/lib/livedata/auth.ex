defmodule Livedata.Auth do
  @moduledoc """
  Session-level auth API: store, retrieve, and validate a Cognito-issued
  user identity in the Plug cookie session.

  @req: KR 8.3
  """

  import Plug.Conn

  @user_key "cognito_user"

  @doc "The session key under which the Cognito user identity is stored."
  @spec user_key() :: String.t()
  def user_key, do: @user_key

  @spec put_session_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def put_session_user(conn, user) when is_map(user) do
    session_user = %{
      "sub" => user["sub"],
      "email" => user["email"],
      "name" => user["name"],
      "exp" => user["exp"],
      "refresh_token" => user["refresh_token"],
      "cognito_username" => user["cognito_username"]
    }

    put_session(conn, @user_key, session_user)
  end

  @spec get_session_user(Plug.Conn.t()) :: map() | nil
  def get_session_user(conn), do: get_session(conn, @user_key)

  @doc "Reads the session user from a raw session map — for use in LiveView on_mount callbacks."
  @spec get_session_user_from_session(map()) :: map() | nil
  def get_session_user_from_session(session), do: Map.get(session, @user_key)

  @spec delete_session(Plug.Conn.t()) :: Plug.Conn.t()
  def delete_session(conn) do
    conn
    |> configure_session(renew: true)
    |> delete_session(@user_key)
  end

  @spec session_user_authenticated?(Plug.Conn.t()) :: boolean()
  def session_user_authenticated?(conn) do
    case get_session_user(conn) do
      nil -> false
      user -> not token_expired?(user)
    end
  end

  @doc "Returns true when the user's ID token has expired or lacks an exp claim."
  @spec token_expired?(map()) :: boolean()
  def token_expired?(%{"exp" => exp}) when is_integer(exp) do
    DateTime.utc_now() |> DateTime.to_unix() >= exp
  end

  def token_expired?(_), do: true
end
