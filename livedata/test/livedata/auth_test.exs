defmodule Livedata.AuthTest do
  use LivedataWeb.ConnCase, async: true

  alias Livedata.Auth

  setup %{conn: conn} do
    {:ok, conn: Phoenix.ConnTest.init_test_session(conn, %{})}
  end

  @user %{"sub" => "abc123", "email" => "test@example.com", "name" => "Test User"}

  defp future_exp, do: DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix()
  defp past_exp, do: DateTime.utc_now() |> DateTime.add(-1) |> DateTime.to_unix()

  describe "put_session_user/2 and get_session_user/1" do
    test "stores and retrieves user from session", %{conn: conn} do
      conn = Auth.put_session_user(conn, Map.put(@user, "exp", future_exp()))
      user = Auth.get_session_user(conn)
      assert user["sub"] == "abc123"
      assert user["email"] == "test@example.com"
    end

    test "persists cognito_username to session", %{conn: conn} do
      full_user =
        @user
        |> Map.put("exp", future_exp())
        |> Map.put("cognito_username", "testuser")
        |> Map.put("refresh_token", "rt_abc")

      conn = Auth.put_session_user(conn, full_user)
      user = Auth.get_session_user(conn)
      assert user["cognito_username"] == "testuser"
      assert user["refresh_token"] == "rt_abc"
    end

    test "returns nil when no user in session", %{conn: conn} do
      assert Auth.get_session_user(conn) == nil
    end
  end

  describe "delete_session/1" do
    test "removes user from session", %{conn: conn} do
      conn =
        conn
        |> Auth.put_session_user(Map.put(@user, "exp", future_exp()))
        |> Auth.delete_session()

      assert Auth.get_session_user(conn) == nil
    end
  end

  describe "session_user_authenticated?/1" do
    test "returns true for valid unexpired session", %{conn: conn} do
      conn = Auth.put_session_user(conn, Map.put(@user, "exp", future_exp()))
      assert Auth.session_user_authenticated?(conn)
    end

    test "returns false when no session", %{conn: conn} do
      refute Auth.session_user_authenticated?(conn)
    end

    test "returns false when token is expired", %{conn: conn} do
      conn = Auth.put_session_user(conn, Map.put(@user, "exp", past_exp()))
      refute Auth.session_user_authenticated?(conn)
    end

    test "returns false when exp is missing", %{conn: conn} do
      conn = Auth.put_session_user(conn, @user)
      refute Auth.session_user_authenticated?(conn)
    end
  end
end
