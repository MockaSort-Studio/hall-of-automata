defmodule LivedataWeb.UserAuthTest do
  use LivedataWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @expired_claims %{
    "sub" => "abc",
    "email" => "user@example.com",
    "name" => "Test User",
    "exp" => DateTime.utc_now() |> DateTime.add(-10) |> DateTime.to_unix(),
    "refresh_token" => nil
  }

  describe "live routes behind :authenticated session" do
    test "authenticated user reaches the dashboard", %{conn: conn} do
      conn = log_in_user(conn)

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Your portfolio"
    end

    test "unauthenticated request is redirected to /login", %{conn: conn} do
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/")
      assert path == "/login"
    end

    test "expired token without refresh_token redirects to /login", %{conn: conn} do
      conn = Phoenix.ConnTest.init_test_session(conn, %{"cognito_user" => @expired_claims})

      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/")
      assert path == "/login"
    end

    test "expired token with valid refresh_token triggers silent refresh", %{conn: conn} do
      expired_with_refresh =
        Map.put(@expired_claims, "refresh_token", "mock_refresh_token")

      conn = Phoenix.ConnTest.init_test_session(conn, %{"cognito_user" => expired_with_refresh})

      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/")
      assert String.starts_with?(path, "/auth/session/")
    end

    test "unauthenticated GET stores auth_return_to in session via browser pipeline", %{
      conn: conn
    } do
      # store_return_to plug in the :browser pipeline sets auth_return_to on GET requests
      conn = get(conn, ~p"/measurements/new")
      assert get_session(conn, "auth_return_to") == "/measurements/new"
    end
  end

  describe "live routes behind :admin session" do
    test "admin user reaches /admin", %{conn: conn} do
      conn = log_in_admin(conn)

      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Admin"
    end

    test "unauthenticated request to /admin redirects to /login", %{conn: conn} do
      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/admin")
      assert path == "/login"
    end

    test "non-admin authenticated user hitting /admin is redirected to /", %{conn: conn} do
      conn = log_in_user(conn)

      {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/admin")
      assert path == "/"
    end
  end
end
