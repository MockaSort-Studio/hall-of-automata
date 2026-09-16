defmodule LivedataWeb.Router do
  use LivedataWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LivedataWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :store_return_to
  end

  defp store_return_to(conn, _opts) do
    if conn.method == "GET" and conn.request_path != "/login" do
      Plug.Conn.put_session(conn, "auth_return_to", Phoenix.Controller.current_path(conn))
    else
      conn
    end
  end

  # ── Unauthenticated routes ────────────────────────────────────────────────
  scope "/", LivedataWeb do
    pipe_through :browser

    live "/login", LoginLive
  end

  scope "/auth", LivedataWeb do
    pipe_through :browser

    get "/session/:token", AuthController, :session
    delete "/", AuthController, :delete
  end

  # ── Authenticated app routes ──────────────────────────────────────────────
  scope "/", LivedataWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: {LivedataWeb.UserAuth, :require_authenticated_user} do
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

  # ── Admin routes — admins group only ─────────────────────────────────────
  # @req: KR 4.1
  scope "/", LivedataWeb do
    pipe_through :browser

    live_session :admin,
      on_mount: {LivedataWeb.UserAuth, :require_admin_user} do
      live "/admin", AdminLive
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
