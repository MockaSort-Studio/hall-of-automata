defmodule Livedata.Auth.CognitoTest do
  use ExUnit.Case, async: false

  alias Livedata.Auth.Cognito

  # Minimal valid RS256 JWT with the right structure for Joken to peek at.
  # The signature is invalid — we only test the Cognito HTTP layer here, not JWT
  # validation, so we stop before the token reaches validate_id_token/1.
  @fake_id_token "eyJraWQiOiJ0ZXN0a2lkIiwiYWxnIjoiUlMyNTYifQ." <>
                   "eyJzdWIiOiJ1c2VyLTEiLCJlbWFpbCI6InVzZXJAdGVzdC5sb2NhbCIsIm5hbWUiOiJUZXN0IFVzZXIiLCJjb2duaXRvOnVzZXJuYW1lIjoidXNlci0xIiwiZXhwIjo5OTk5OTk5OTk5fQ." <>
                   "invalidsig"

  defp cognito_success_body do
    Jason.encode!(%{
      "AuthenticationResult" => %{
        "IdToken" => @fake_id_token,
        "AccessToken" => "access-token",
        "RefreshToken" => "refresh-token",
        "ExpiresIn" => 3600,
        "TokenType" => "Bearer"
      },
      "ChallengeParameters" => %{}
    })
  end

  defp assert_cognito_headers(conn) do
    assert List.keyfind(conn.req_headers, "content-type", 0) ==
             {"content-type", "application/x-amz-json-1.1"}

    assert List.keyfind(conn.req_headers, "x-amz-target", 0) ==
             {"x-amz-target", "AWSCognitoIdentityProviderService.InitiateAuth"}
  end

  describe "authenticate/2" do
    test "maps Cognito error response to tagged error tuple" do
      Req.Test.stub(Livedata.Auth.Cognito, fn conn ->
        assert_cognito_headers(conn)

        # Cognito responds with application/x-amz-json-1.1 (not application/json)
        # so Req returns the body as a raw JSON string. Both success and error
        # paths must decode manually.
        conn
        |> Plug.Conn.put_resp_content_type("application/x-amz-json-1.1")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            "__type" => "NotAuthorizedException",
            "message" => "Incorrect username or password."
          })
        )
      end)

      assert {:error, {"NotAuthorizedException", "Incorrect username or password."}} =
               Cognito.authenticate("user@example.com", "any-password")
    end

    test "decodes 200 response body and proceeds to JWT validation" do
      Req.Test.stub(Livedata.Auth.Cognito, fn conn ->
        assert_cognito_headers(conn)

        conn
        |> Plug.Conn.put_resp_content_type("application/x-amz-json-1.1")
        |> Plug.Conn.send_resp(200, cognito_success_body())
      end)

      # JWT validation will fail (fake token) — that's expected.
      # The important thing is we do NOT get an Access.get/3 crash, which would
      # mean the raw string body was not decoded before indexing into it.
      assert {:error, {:jwt_invalid, _}} =
               Cognito.authenticate("user@example.com", "correct-password")
    end
  end
end
