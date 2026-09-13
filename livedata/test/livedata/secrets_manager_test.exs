defmodule Livedata.SecretsManagerTest do
  use ExUnit.Case, async: true

  alias Livedata.SecretsManager

  describe "parse_rds_secret!/1" do
    test "returns Ecto keyword list from valid RDS secret JSON" do
      json =
        Jason.encode!(%{
          "username" => "dbadmin",
          "password" => "s3cr3t",
          "host" => "a2t-mrv-db.abc123.eu-west-1.rds.amazonaws.com",
          "port" => 5432,
          "dbname" => "livedata_prod",
          "engine" => "postgres"
        })

      result = SecretsManager.parse_rds_secret!(json)

      assert result[:hostname] == "a2t-mrv-db.abc123.eu-west-1.rds.amazonaws.com"
      assert result[:port] == 5432
      assert result[:username] == "dbadmin"
      assert result[:password] == "s3cr3t"
      assert result[:database] == "livedata_prod"
    end

    test "raises when required fields are missing" do
      json = Jason.encode!(%{"username" => "dbadmin", "password" => "s3cr3t"})

      assert_raise RuntimeError, ~r/missing expected fields/, fn ->
        SecretsManager.parse_rds_secret!(json)
      end
    end

    test "raises on invalid JSON" do
      assert_raise RuntimeError, ~r/Failed to parse RDS secret JSON/, fn ->
        SecretsManager.parse_rds_secret!("not-valid-json{")
      end
    end
  end
end
