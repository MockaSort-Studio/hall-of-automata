defmodule LivedataWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use LivedataWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint LivedataWeb.Endpoint

      use LivedataWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import LivedataWeb.ConnCase
    end
  end

  setup tags do
    Livedata.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Puts a fake non-admin Cognito identity into the conn session so live routes behind
  the `:authenticated` live_session pass the `UserAuth.on_mount` guard.
  """
  def log_in_user(conn) do
    user = %{
      "sub" => "test-sub-#{System.unique_integer([:positive])}",
      "email" => "test@example.com",
      "name" => "Test User",
      "exp" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix(),
      "is_admin" => false
    }

    Phoenix.ConnTest.init_test_session(conn, %{"cognito_user" => user})
  end

  @doc """
  Puts a fake admin Cognito identity into the conn session so live routes behind
  the `:admin` live_session pass the `UserAuth.on_mount` guard.
  """
  def log_in_admin(conn) do
    user = %{
      "sub" => "admin-sub-#{System.unique_integer([:positive])}",
      "email" => "admin@example.com",
      "name" => "Admin User",
      "exp" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix(),
      "is_admin" => true
    }

    Phoenix.ConnTest.init_test_session(conn, %{"cognito_user" => user})
  end
end
