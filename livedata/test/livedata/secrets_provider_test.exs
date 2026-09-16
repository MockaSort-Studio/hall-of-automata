defmodule Livedata.SecretsProviderTest do
  use ExUnit.Case, async: false

  alias Livedata.SecretsProvider

  @base_config [livedata: [{Livedata.Repo, [types: Livedata.PostgrexTypes]}]]

  setup do
    vars =
      ~w(DATABASE_URL_PR DATABASE_URL_MAIN DATABASE_URL SECRET_KEY_BASE DATABASE_SSL DATABASE_SSL_CACERTFILE POOL_SIZE ECTO_IPV6)

    saved = Enum.map(vars, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end)

    Enum.each(vars, &System.delete_env/1)
    :ok
  end

  describe "load/2 — no credentials configured" do
    test "returns config unchanged when no env vars are set" do
      result = SecretsProvider.load(@base_config, [])
      assert result == @base_config
    end

    test "returns config unchanged when DATABASE_URL vars are all blank strings" do
      System.put_env("DATABASE_URL_PR", "")
      System.put_env("DATABASE_URL_MAIN", "")
      System.put_env("DATABASE_URL", "")
      result = SecretsProvider.load(@base_config, [])
      assert result == @base_config
    end
  end

  describe "load/2 — DATABASE_URL path" do
    test "merges Repo config from DATABASE_URL_MAIN" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      result = SecretsProvider.load(@base_config, [])
      repo = get_repo_config(result)
      assert repo[:url] == "ecto://user:pass@host/mydb"
      assert repo[:ssl] == true
    end

    test "DATABASE_URL_PR takes precedence over DATABASE_URL_MAIN" do
      System.put_env("DATABASE_URL_PR", "ecto://pr/prdb")
      System.put_env("DATABASE_URL_MAIN", "ecto://main/maindb")
      result = SecretsProvider.load(@base_config, [])
      assert get_repo_config(result)[:url] == "ecto://pr/prdb"
    end

    test "DATABASE_URL_MAIN takes precedence over DATABASE_URL" do
      System.put_env("DATABASE_URL_MAIN", "ecto://main/maindb")
      System.put_env("DATABASE_URL", "ecto://legacy/legacydb")
      result = SecretsProvider.load(@base_config, [])
      assert get_repo_config(result)[:url] == "ecto://main/maindb"
    end

    test "falls through to DATABASE_URL when PR and MAIN are blank" do
      System.put_env("DATABASE_URL_PR", "")
      System.put_env("DATABASE_URL_MAIN", "")
      System.put_env("DATABASE_URL", "ecto://legacy/legacydb")
      result = SecretsProvider.load(@base_config, [])
      assert get_repo_config(result)[:url] == "ecto://legacy/legacydb"
    end

    test "DATABASE_SSL=false disables TLS" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      System.put_env("DATABASE_SSL", "false")
      result = SecretsProvider.load(@base_config, [])
      assert get_repo_config(result)[:ssl] == false
    end

    test "POOL_SIZE is applied" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      System.put_env("POOL_SIZE", "3")
      result = SecretsProvider.load(@base_config, [])
      assert get_repo_config(result)[:pool_size] == 3
    end

    test "DATABASE_SSL_CACERTFILE sets verify_peer SSL" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      System.put_env("DATABASE_SSL_CACERTFILE", "/etc/livedata/rds-ca-bundle.pem")
      result = SecretsProvider.load(@base_config, [])

      assert get_repo_config(result)[:ssl] == [
               verify: :verify_peer,
               cacertfile: "/etc/livedata/rds-ca-bundle.pem"
             ]
    end

    test "does not patch Endpoint when SECRET_KEY_BASE is unset" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      result = SecretsProvider.load(@base_config, [])
      refute get_endpoint_config(result)[:secret_key_base]
    end

    test "patches Endpoint when SECRET_KEY_BASE is set" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      System.put_env("SECRET_KEY_BASE", "my_secret_key_base")
      result = SecretsProvider.load(@base_config, [])
      assert get_endpoint_config(result)[:secret_key_base] == "my_secret_key_base"
    end

    test "DB and secret_key_base are both merged in one pass" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      System.put_env("SECRET_KEY_BASE", "my_secret_key_base")
      result = SecretsProvider.load(@base_config, [])
      assert get_repo_config(result)[:url] == "ecto://user:pass@host/mydb"
      assert get_endpoint_config(result)[:secret_key_base] == "my_secret_key_base"
    end
  end

  defp get_repo_config(config) do
    config
    |> Keyword.get(:livedata, [])
    |> Keyword.get(Livedata.Repo, [])
  end

  defp get_endpoint_config(config) do
    config
    |> Keyword.get(:livedata, [])
    |> Keyword.get(LivedataWeb.Endpoint, [])
  end
end
