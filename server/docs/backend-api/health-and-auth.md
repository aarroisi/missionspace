# Health and Auth APIs

## Endpoint summary

| Method | Path | Auth required | Notes |
| --- | --- | --- | --- |
| GET | `/health` | No | Liveness check |
| POST | `/api/auth/register` | No | Creates workspace + first user, logs in |
| POST | `/api/auth/login` | No | Logs in with email/password |
| POST | `/api/auth/logout` | No | Clears session if present |
| GET | `/api/auth/me` | Session expected | Public route that reads session directly |
| PUT | `/api/auth/me` | Yes | Updates current user profile |
| POST | `/api/auth/verify-email` | No | Verifies email by token |
| POST | `/api/auth/forgot-password` | No | Starts password reset flow |
| POST | `/api/auth/reset-password` | No | Resets password by token |
| POST | `/api/auth/resend-verification` | Yes | Resends verification email |
| GET | `/api/api-keys` | Yes | Lists API keys for current user |
| GET | `/api/api-keys/scopes` | Yes | Returns available scopes for current user's role |
| POST | `/api/api-keys` | Yes | Creates API key for current user |
| DELETE | `/api/api-keys/:id` | Yes | Revokes API key owned by current user |
| GET | `/api/api-keys/verify` | API key | Verifies provided API key and returns key/user summary |

## GET `/health`

- Request: none
- Response `200`: `{"status":"ok"}`

## POST `/api/auth/register`

- Request body (top-level):

```json
{
  "workspace_name": "Acme",
  "name": "Alice",
  "email": "alice@example.com",
  "password": "password123"
}
```

- Behavior:
  - Creates workspace and first user.
  - Sets session (`user_id`, `workspace_id`).
  - Sends verification email.
- Response `201`:

```json
{
  "user": "AuthUser",
  "workspace": "WorkspaceSummary"
}
```

- Errors:
  - `422` validation errors from workspace/user changesets

## POST `/api/auth/login`

- Request body:

```json
{
  "email": "alice@example.com",
  "password": "password123"
}
```

- Behavior:
  - Authenticates active user with password hash comparison.
  - Sets session before email-verification gate.
- Success response `200`:

```json
{
  "user": "AuthUser",
  "workspace": "WorkspaceSummary"
}
```

- Failure cases:
  - `401` `{"error":"Invalid email or password"}`
  - `403` `{"error":"email_not_verified"}`

## POST `/api/auth/logout`

- Request: none
- Behavior: clears session
- Response `200`: `{"message":"Logged out successfully"}`

## GET `/api/auth/me`

- Request: none
- Behavior:
  - Reads `:user_id` from session (not via AuthPlug).
  - Returns current user + workspace.
- Success `200`:

```json
{
  "user": "AuthUser",
  "workspace": "WorkspaceSummary"
}
```

- Failure cases:
  - `401` `{"error":"Not authenticated"}`
  - `401` `{"error":"User not found"}`
  - `403` `{"error":"email_not_verified"}`

## PUT `/api/auth/me`

- Auth: required
- Request body (wrapped):

```json
{
  "user": {
    "name": "New Name",
    "email": "new@example.com",
    "avatar": "https://...",
    "timezone": "America/New_York"
  }
}
```

- Notes:
  - Only `name`, `email`, `avatar`, `timezone` are accepted.
  - Extra fields are ignored by controller before update.
- Response `200`:

```json
{
  "user": "AuthUser",
  "workspace": "WorkspaceSummary"
}
```

- Errors:
  - `401` if not authenticated
  - `422` invalid email/name, duplicate email, etc.

## POST `/api/auth/verify-email`

- Request body:

```json
{
  "token": "verification-token"
}
```

- Success `200`: `{"message":"Email verified successfully"}`
- Failure `400`: `{"error":"Invalid or expired verification token"}`

## POST `/api/auth/forgot-password`

- Request body:

```json
{
  "email": "alice@example.com"
}
```

- Behavior:
  - If account exists, creates reset token and sends email.
  - Always returns success message to avoid email enumeration.
- Response `200`:

```json
{
  "message": "If an account exists with that email, we sent a password reset link"
}
```

## POST `/api/auth/reset-password`

- Request body:

```json
{
  "token": "reset-token",
  "password": "newpassword123"
}
```

- Success `200`: `{"message":"Password reset successfully"}`
- Failure cases:
  - `400` `{"error":"Invalid reset token"}`
  - `400` `{"error":"Reset token has expired"}`
  - `422` password validation errors

## POST `/api/auth/resend-verification`

- Auth: required
- Behavior:
  - If already verified: returns informational message.
  - Otherwise generates a new token and sends verification email.
- Responses:
  - `200` `{"message":"Email already verified"}`
  - `200` `{"message":"Verification email sent"}`
  - `500` `{"error":"Failed to send verification email"}`

## API key endpoints

API keys are attached to users (not directly to workspaces). Workspace context is derived from the attached user.

### GET `/api/api-keys`

- Auth: required (session or API key)
- Returns active (non-revoked) API keys owned by current user.
- Response `200`: `{"data":[ApiKey...]}`

### GET `/api/api-keys/scopes`

- Auth: required
- Returns role-allowed scopes for current user.
- Response `200`:

```json
{
  "data": {
    "scopes": ["item:view", "item:create"]
  }
}
```

### POST `/api/api-keys`

- Auth: required
- Request body (top-level):

```json
{
  "name": "CI Integration",
  "scopes": ["item:view", "item:create"]
}
```

- Notes:
  - `name` is required.
  - `scopes` is optional; when omitted, backend defaults to all scopes allowed by current role.
  - Requested scopes must be a subset of role scopes.
  - Plaintext key is returned **once** in this response only.
- Response `201`:

```json
{
  "data": {
    "id": "uuid",
    "name": "CI Integration",
    "key_prefix": "brk_xxxxxxxx",
    "scopes": ["item:view", "item:create"],
    "key": "brk_very_long_secret",
    "verify_endpoint": "/api/api-keys/verify"
  }
}
```

- Errors:
  - `422` validation errors
  - `422` invalid/unauthorized scopes

### DELETE `/api/api-keys/:id`

- Auth: required
- Revokes key if owned by current user.
- Response `204` empty body
- Errors: `404` if key not found or not owned by user

### GET `/api/api-keys/verify`

- Auth: API key only
- Provide key via:
  - `X-API-Key: brk_...`, or
  - `Authorization: Bearer brk_...`
- Behavior:
  - Returns `401` when key is invalid/revoked.
  - Returns `200` with key + user + effective scopes when valid.
- Response `200`:

```json
{
  "data": {
    "valid": true,
    "auth_method": "api_key",
    "api_key": "ApiKey",
    "user": {
      "id": "uuid",
      "name": "string",
      "email": "string",
      "role": "owner|member|guest",
      "workspace_id": "uuid"
    },
    "scopes": ["item:view", "item:create"]
  }
}
```
