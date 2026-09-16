# Livedata.Auth — authentication

Modules implementing USER_PASSWORD_AUTH against Cognito and session management.

## Modules

| Module | Role |
|---|---|
| `Livedata.Auth.Provider` | Public entry point — `authenticate/2` and `refresh_token/2`. Callers use only this. |
| `Livedata.Auth.ProviderBehaviour` | Behaviour contract for authentication backends |
| `Livedata.Auth.Cognito` | Production backend: USER_PASSWORD_AUTH via Cognito InitiateAuth API |
| `Livedata.Auth.CognitoMock` | Dev/test/preview backend: accepts any username with the configured bypass password |
| `Livedata.Auth.Secrets` | Fetches and caches Cognito credentials from AWS Secrets Manager and SSM |
| `Livedata.Auth.SessionBridge` | Short-lived ETS token bridge from LiveView to Plug session cookie |

The session-level API (store/retrieve/delete user identity, check token expiry) lives in
`Livedata.Auth` (`lib/livedata/auth.ex`).

## Auth flow

```
Browser → POST /login (LiveView form)
  → Provider.authenticate/2
    → Cognito.authenticate/2  (or CognitoMock in dev/test)
  → SessionBridge.store/1 → redirect to /auth/session/:token
  → AuthController.session/2 → Auth.put_session_user/2 → redirect to return_to
```

## Backend selection

The active backend is configured via `:auth_provider` in application config:

| Environment | Backend |
|---|---|
| Production (EC2) | `Livedata.Auth.Cognito` |
| Dev / test / Render preview | `Livedata.Auth.CognitoMock` |

## Configuration

| Key | Source |
|---|---|
| `auth_provider` | `config/*.exs` or `runtime.exs` |
| `auth_bypass_password` | `AUTH_BYPASS_PASSWORD` env var (CognitoMock only) |
| `cognito_issuer_url` | SSM `/a2t-mrv/cognito/region` + `/user-pool-id`, or `COGNITO_ISSUER_URL` env var |
| `cognito_secret_name` | `COGNITO_SECRET_NAME` env var (default: `a2t-mrv/cognito/client-secret`) |
| `cognito_credentials` | Fetched from Secrets Manager, cached in Application env |

In dev and test, `cognito_credentials` can be set directly in config to bypass Secrets Manager.
