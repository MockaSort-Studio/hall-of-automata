defmodule LivedataWeb.AuthController do
  @moduledoc """
  Session bridge and logout for the LiveView login flow.

  GET /auth/session/:token — reads a one-time bridge token written by LoginLive
  after successful Cognito auth, writes the Plug session cookie, then redirects
  to the app. Replacing the OIDC callback flow.

  DELETE /auth — clears the session and redirects to /login.

  @req: KR 8.3
  """

  use LivedataWeb, :controller

  alias Livedata.Auth
  alias Livedata.Auth.SessionBridge

  @doc "Reads the bridge token, writes the Plug session, and redirects."
  def session(conn, %{"token" => token} = params) do
    return_to = Map.get(params, "return_to", "/")

    case SessionBridge.fetch(token) do
      {:ok, user} ->
        conn
        |> Auth.put_session_user(user)
        |> delete_session("auth_return_to")
        |> redirect(to: return_to)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Session token expired or invalid. Please sign in again.")
        |> redirect(to: "/login")
    end
  end

  @doc "Signs the user out, clears the Plug session, and redirects to /login."
  def delete(conn, _params) do
    conn
    |> Auth.delete_session()
    |> redirect(to: "/login")
  end
end
