defmodule LivedataWeb.UserAuth do
  @moduledoc """
  LiveView on_mount hooks for Cognito-based authentication.

  Used in the router's `live_session :authenticated` block to gate all
  protected routes. Unauthenticated or expired sessions are redirected to
  the Cognito login initiation path.

  The `auth_return_to` session key is written by the `store_return_to` plug
  in the `:browser` pipeline (router.ex) on every GET request, so that after
  a successful login the user is returned to the page they requested.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  @doc "Mounts hook: requires a valid, unexpired Cognito session to continue."
  def on_mount(:ensure_authenticated, _params, session, socket) do
    case Map.get(session, Livedata.Auth.user_key()) do
      nil ->
        {:halt, redirect(socket, to: "/auth/cognito")}

      user when is_map(user) ->
        if Livedata.Auth.token_expired?(user) do
          {:halt, redirect(socket, to: "/auth/cognito")}
        else
          {:cont, assign(socket, :current_user, user)}
        end
    end
  end
end
