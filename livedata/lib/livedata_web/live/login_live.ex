defmodule LivedataWeb.LoginLive do
  @moduledoc """
  Username/password login form. Authenticates via the configured auth provider
  and bridges the resulting user identity to the Plug session via the
  AuthController session bridge.

  @req: KR 8.3
  """

  use LivedataWeb, :live_view

  alias Livedata.Auth.Provider
  alias Livedata.Auth.SessionBridge

  @impl true
  def mount(_params, session, socket) do
    return_to = Map.get(session, "auth_return_to", "/")

    socket =
      socket
      |> assign(:return_to, return_to)
      |> assign(:form, to_form(%{"username" => "", "password" => ""}, as: :login))
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "submit",
        %{"login" => %{"username" => username, "password" => password}},
        socket
      ) do
    case Provider.authenticate(username, password) do
      {:ok, user} ->
        token = SessionBridge.store(user)
        return_to = URI.encode_www_form(socket.assigns.return_to)

        {:noreply, push_navigate(socket, to: "/auth/session/#{token}?return_to=#{return_to}")}

      {:error, _reason} ->
        {:noreply, assign(socket, :error, "Invalid username or password.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="login-page" class="flex min-h-[60vh] items-center justify-center">
        <div class="w-full max-w-sm space-y-6">
          <div class="text-center">
            <h1 class="text-2xl font-semibold tracking-tight">Sign in</h1>
            <p class="mt-1 text-sm text-base-content/60">Air2Tree Measurement Platform</p>
          </div>

          <.form
            for={@form}
            id="login-form"
            phx-submit="submit"
            class="space-y-4"
          >
            <.input
              field={@form[:username]}
              type="text"
              label="Username"
              id="login-username"
              autocomplete="username"
              required
            />
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              id="login-password"
              autocomplete="current-password"
              required
            />

            <p :if={@error} id="login-error" class="text-sm text-error">{@error}</p>

            <button
              id="login-submit"
              type="submit"
              class="btn btn-primary w-full"
            >
              Sign in
            </button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
