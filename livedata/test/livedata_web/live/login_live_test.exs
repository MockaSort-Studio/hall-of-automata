defmodule LivedataWeb.LoginLiveTest do
  use LivedataWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @bypass_password "test_bypass_password"

  describe "login page" do
    test "renders the login form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      assert has_element?(view, "#login-form")
      assert has_element?(view, "#login-username")
      assert has_element?(view, "#login-password")
      assert has_element?(view, "#login-submit")
    end

    test "shows inline error on wrong password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      view
      |> form("#login-form", login: %{username: "user", password: "wrong"})
      |> render_submit()

      assert has_element?(view, "#login-error", "Invalid username or password")
    end

    test "redirects to session bridge on correct password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      result =
        view
        |> form("#login-form", login: %{username: "user", password: @bypass_password})
        |> render_submit()

      assert {:error, {:live_redirect, %{to: path}}} = result
      assert String.starts_with?(path, "/auth/session/")
    end

    test "session bridge token completes sign-in and grants access", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      {:error, {:live_redirect, %{to: bridge_path}}} =
        view
        |> form("#login-form", login: %{username: "user", password: @bypass_password})
        |> render_submit()

      # Follow the bridge redirect to write the Plug session
      conn = get(conn, bridge_path)
      assert redirected_to(conn) == "/"

      # The session now has a user — authenticated routes are reachable
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Your portfolio"
    end

    test "already logged-in users can still view the login page", %{conn: conn} do
      conn = log_in_user(conn)
      {:ok, _view, _html} = live(conn, ~p"/login")
    end
  end
end
