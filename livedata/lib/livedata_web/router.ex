defmodule LivedataWeb.Router do
  use LivedataWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LivedataWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Store the current path on every GET so `auth_return_to` is available
    # in the session when the Cognito callback fires after login.
    plug :store_return_to
  end

  defp store_return_to(%{method: "GET", request_path: path} = conn, _opts) do
    if String.starts_with?(path, "/auth/") do
      conn
    else
      Plug.Conn.put_session(conn, "auth_return_to", path)
    end
  end

  defp store_return_to(conn, _opts), do: conn

  # ── Auth routes (unauthenticated) ─────────────────────────────────────────
  scope "/auth", LivedataWeb do
    pipe_through :browser

    get "/cognito", AuthController, :new
    get "/cognito/callback", AuthController, :callback
    delete "/cognito", AuthController, :delete
  end

  # ── Authenticated routes ───────────────────────────────────────────────────
  scope "/", LivedataWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: {LivedataWeb.UserAuth, :ensure_authenticated} do
      live "/", DashboardLive
      live "/projects/new", ProjectRegistrationLive
      live "/projects/:id", ProjectShowLive
      # @req: CRCF-34 — a project accumulates activities beyond the first
      live "/projects/:project_id/activities/new", ActivityNewLive
      live "/activities/:id", ActivityShowLive
      live "/measurements/new", MeasurementEntryLive
      live "/measurements/upload", MeasurementUploadLive
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:livedata, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LivedataWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
