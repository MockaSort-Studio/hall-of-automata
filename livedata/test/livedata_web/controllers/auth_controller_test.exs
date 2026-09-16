defmodule LivedataWeb.AuthControllerTest do
  use LivedataWeb.ConnCase, async: true

  alias Livedata.Auth
  alias Livedata.Auth.SessionBridge

  setup %{conn: conn} do
    {:ok, conn: Phoenix.ConnTest.init_test_session(conn, %{})}
  end

  @user %{
    "sub" => "user-123",
    "email" => "user@example.com",
    "name" => "Test User",
    "exp" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix(),
    "refresh_token" => "rt_abc"
  }

  describe "GET /auth/session/:token" do
    test "reads bridge token, writes session, and redirects to /", %{conn: conn} do
      token = SessionBridge.store(@user)
      conn = get(conn, ~p"/auth/session/#{token}")

      assert redirected_to(conn) == "/"
      assert Auth.get_session_user(conn)["sub"] == "user-123"
      assert Auth.get_session_user(conn)["email"] == "user@example.com"
    end

    test "honours return_to query param", %{conn: conn} do
      token = SessionBridge.store(@user)
      conn = get(conn, ~p"/auth/session/#{token}", return_to: "/projects/new")

      assert redirected_to(conn) == "/projects/new"
    end

    test "token is single-use — second request redirects to /login", %{conn: conn} do
      token = SessionBridge.store(@user)
      _conn1 = get(Phoenix.ConnTest.build_conn(), ~p"/auth/session/#{token}")

      conn2 = get(conn, ~p"/auth/session/#{token}")
      assert redirected_to(conn2) == "/login"
    end

    test "unknown token redirects to /login with flash", %{conn: conn} do
      conn = get(conn, ~p"/auth/session/invalid_token_xyz")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "expired or invalid"
    end

    test "clears auth_return_to from session on success", %{conn: conn} do
      token = SessionBridge.store(@user)

      conn =
        conn
        |> put_session("auth_return_to", "/measurements/new")
        |> get(~p"/auth/session/#{token}")

      assert get_session(conn, "auth_return_to") == nil
    end
  end

  describe "DELETE /auth" do
    test "clears session and redirects to /login", %{conn: conn} do
      conn =
        conn
        |> Auth.put_session_user(@user)
        |> delete(~p"/auth")

      assert Auth.get_session_user(conn) == nil
      assert redirected_to(conn) == "/login"
    end
  end
end
