defmodule LivedataWeb.UserAuth do
  @moduledoc """
  LiveView on_mount guards and router plugs for session authentication.

  Protects live routes under the :authenticated live_session: unauthenticated
  mounts redirect to /login. Expired tokens trigger a silent REFRESH_TOKEN_AUTH
  attempt before forcing re-login.

  The :admin live_session uses require_admin_user, which additionally redirects
  authenticated non-admin users to /.

  @req: KR 8.3
  @req: KR 4.1
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Livedata.Auth
  alias Livedata.Auth.Provider
  alias Livedata.Auth.SessionBridge

  @doc """
  on_mount guards for authenticated routes:
  - :require_authenticated_user — redirects unauthenticated or irreversibly-expired mounts to /login
  - :require_admin_user — additionally redirects non-admin authenticated users to /
  """
  def on_mount(key, params, session, socket)

  def on_mount(:require_authenticated_user, _params, session, socket) do
    case Auth.get_session_user_from_session(session) do
      nil ->
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/login")}

      user ->
        if Auth.token_expired?(user) do
          handle_expired(user, socket)
        else
          {:cont, Phoenix.Component.assign(socket, :current_user, user)}
        end
    end
  end

  def on_mount(:require_admin_user, _params, session, socket) do
    case Auth.get_session_user_from_session(session) do
      nil ->
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/login")}

      user ->
        if Auth.token_expired?(user) do
          handle_expired(user, socket)
        else
          if user["is_admin"] do
            {:cont, Phoenix.Component.assign(socket, :current_user, user)}
          else
            {:halt, Phoenix.LiveView.push_navigate(socket, to: "/")}
          end
        end
    end
  end

  defp handle_expired(%{"refresh_token" => rt} = user, socket) when is_binary(rt) do
    username = user["cognito_username"] || user["sub"] || ""

    case Provider.refresh_token(username, rt) do
      {:ok, new_user} ->
        token = SessionBridge.store(new_user)
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/auth/session/#{token}")}

      {:error, _} ->
        {:halt, Phoenix.LiveView.push_navigate(socket, to: "/login")}
    end
  end

  defp handle_expired(_, socket) do
    {:halt, Phoenix.LiveView.push_navigate(socket, to: "/login")}
  end

  @doc "Plug: redirects unauthenticated requests in non-live routes."
  def require_authenticated_user(conn, _opts) do
    if Auth.session_user_authenticated?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: "/login")
      |> halt()
    end
  end
end
