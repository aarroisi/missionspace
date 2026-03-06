# HTTP Conventions

## Base behavior

- Primary API namespace: `/api`
- JSON request/response format throughout (`accepts ["json"]` pipeline)
- Authentication supports both:
  - Session cookie (`_bridge_key`)
  - User API keys (`brk_...`) via header

## Authentication model

- Session cookie key: `_bridge_key`
- Session max age: `1209600` seconds (14 days)
- Session is set by:
  - `POST /api/auth/register`
  - `POST /api/auth/login`
- Session is cleared by:
  - `POST /api/auth/logout`

### API key model

- API key header options:
  - `X-API-Key: brk_...`
  - `Authorization: Bearer brk_...`
- API keys are attached to users, not directly to workspaces.
- Workspace context is resolved from the attached user.
- Only bearer tokens prefixed with `brk_` are treated as API keys.
- Any other bearer token is ignored by auth plug and session auth is used.

### Protected route behavior (`AuthPlug`)

For authenticated `/api` routes:

- Missing/invalid session/API key -> `401`
- Inactive user (`is_active=false`) -> `401` with `{"error":"Account has been deactivated"}`
- Unverified email -> `403` with `{"error":"email_not_verified"}`
  - Exception: `POST /api/auth/resend-verification` is allowed for unverified users
- Missing workspace on user -> `403`

When API key auth succeeds:

- `conn.assigns.auth_method = :api_key`
- `conn.assigns.current_api_key` is available
- User scopes are set to `api_key.scopes ∩ role_scopes(user.role)`

When session auth succeeds:

- `conn.assigns.auth_method = :session`
- User scopes are set from role defaults

## Authorization model (scope + role + resource)

Roles:

- `owner`
- `member`
- `guest`

Scopes are attached to roles and can be narrowed per API key.

- Non-API-key requests use role scopes directly.
- API key requests use intersection of key scopes and role scopes.
- Policy checks first validate required scope, then run resource-level checks.

High-level rules:

- Workspace/project management is owner-only.
- Non-owners can mutate only items they created (if they can access them).
- Non-owners can access project items only via project membership.
- Guests are limited to one project-or-item membership total.

See `lib/bridge/authorization/policy.ex` for exact behavior.
Scope catalog lives in `lib/bridge/authorization/scopes.ex`.

## Pagination

Cursor pagination is used in list endpoints.

Query params:

- `limit` (integer)
- `after` (cursor)
- `before` (cursor)

Paginated response shape:

```json
{
  "data": [...],
  "metadata": {
    "after": "cursor-or-null",
    "before": "cursor-or-null",
    "limit": 50
  }
}
```

## Common error envelopes

Validation errors (`422`):

```json
{
  "errors": {
    "field_name": ["message"]
  }
}
```

Not found (`404`):

```json
{
  "errors": {
    "detail": "Not Found"
  }
}
```

Forbidden (`403`):

```json
{
  "error": "Forbidden"
}
```

Unauthorized (`401`) may be either:

- `{"errors":{"detail":"Unauthorized"}}`
- `{"error":"Not authenticated"}` (from `GET /api/auth/me`)

## Naming and compatibility quirks

- API naming is not perfectly uniform; some responses contain camelCase keys.
- "Board" maps to `List` in DB:
  - `board` and `list` are aliases in some endpoints.
- `ProjectMember` response uses camelCase keys (`userId`, `projectId`).
- Read-position response uses `lastReadAt` camelCase.
- Message create supports both snake_case and camelCase request keys.

Do not normalize keys in clients unless the endpoint contract is explicitly changed.

## Enumerations used by APIs

- User roles: `owner`, `member`, `guest`
- Visibility: `private`, `shared`
- Star types: `project`, `board`, `doc_folder`, `doc`, `channel`, `direct_message`, `task`
- Subscription item types: `task`, `doc`, `channel`, `dm`, `thread`
- Read-position item types: `channel`, `dm`
- Item-member item types: `list`, `doc_folder`, `channel`
- Project-item item types (API): `board`, `doc_folder`, `channel`
- Project-item item types (DB): `list`, `doc_folder`, `channel`

## API key scopes

Current scope catalog:

- `workspace:members:manage`
- `project:members:manage`
- `project:manage`
- `project:view`
- `item:view`
- `item:create`
- `item:update`
- `item:delete`
- `item:comment`
- `item:members:manage`
- `item:visibility:set`
- `message:view`
- `message:create`
- `message:update`
- `message:delete`
