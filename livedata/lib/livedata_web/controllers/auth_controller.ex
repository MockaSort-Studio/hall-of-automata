defmodule LivedataWeb.AuthController do
  @moduledoc """
  Handles the Cognito OIDC authorization_code flow.
  """

  use LivedataWeb, :controller

  alias Livedata.Auth
  alias Livedata.Auth.Secrets

  @doc "Initiates the Cognito OIDC authorization_code flow."
  def new(conn, _params) do
    cognito = cognito_module()

    case cognito.authorize_url() do
      {:ok, url, session_params} ->
        conn
        |> put_session("cognito_session_params", session_params)
        |> redirect(external: url)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Authentication service unavailable. Please try again later.")
        |> redirect(to: ~p"/")
    end
  end

  @doc "Handles the Cognito callback: exchanges the code, stores the session."
  def callback(conn, params) do
    case get_session(conn, "cognito_session_params") do
      nil ->
        conn
        |> put_flash(:error, "Your session expired, please try again.")
        |> redirect(to: ~p"/auth/cognito")

      session_params ->
        cognito = cognito_module()

        case cognito.exchange_code(params, session_params) do
          {:ok, user, _token} ->
            return_to = get_session(conn, "auth_return_to") || ~p"/"

            conn
            |> delete_session("cognito_session_params")
            |> delete_session("auth_return_to")
            |> Auth.put_session_user(user)
            |> redirect(to: return_to)

          {:error, _reason} ->
            conn
            |> delete_session("cognito_session_params")
            |> put_flash(:error, "Authentication failed. Please try signing in again.")
            |> redirect(to: ~p"/auth/cognito")
        end
    end
  end

  @doc "Signs the user out, clears the session, and redirects to Cognito to end the SSO session."
  def delete(conn, _params) do
    conn = Auth.delete_session(conn)

    case build_cognito_logout_url() do
      {:ok, url} -> redirect(conn, external: url)
      {:error, _} -> redirect(conn, to: ~p"/")
    end
  end

  defp cognito_module do
    Application.get_env(:livedata, :cognito_module, Livedata.Auth.Cognito)
  end

  defp build_cognito_logout_url do
    with hosted_ui_base when is_binary(hosted_ui_base) <-
           Application.get_env(:livedata, :cognito_hosted_ui_base),
         redirect_uri when is_binary(redirect_uri) <-
           Application.get_env(:livedata, :cognito_redirect_uri),
         {:ok, creds} <- Secrets.client_credentials() do
      logout_base =
        URI.parse(redirect_uri) |> Map.merge(%{path: "/", query: nil}) |> URI.to_string()

      url =
        "#{hosted_ui_base}/logout?client_id=#{creds.client_id}&logout_uri=#{URI.encode_www_form(logout_base)}"

      {:ok, url}
    else
      nil -> {:error, :not_configured}
      {:error, reason} -> {:error, reason}
    end
  end
end
