# Workspace and Membership APIs

## Endpoint summary

| Method | Path | Auth required | Notes |
| --- | --- | --- | --- |
| PUT | `/api/workspace` | Yes | Workspace settings update (owner only) |
| GET | `/api/workspace/automation` | Yes | Workspace automation settings (owner only) |
| PUT | `/api/workspace/automation` | Yes | Update workspace automation settings (owner only) |
| GET | `/api/workspace/automation/codex-connection` | Yes | Get Codex credential connection status + OAuth connect URL (owner only) |
| PUT | `/api/workspace/automation/codex-connection` | Yes | Link Codex credentials using ChatGPT OAuth callback code/state (owner only) |
| POST | `/api/workspace/automation/codex-connection/device` | Yes | Start ChatGPT device authorization for Codex connection (owner only) |
| POST | `/api/workspace/automation/codex-connection/device/complete` | Yes | Complete/poll ChatGPT device authorization for Codex connection (owner only) |
| DELETE | `/api/workspace/automation/codex-connection` | Yes | Remove stored Codex credentials (API key or OAuth-derived key) (owner only) |
| GET | `/api/workspace/automation/github-connection` | Yes | Get GitHub App connection status + connect URL (owner only) |
| PUT | `/api/workspace/automation/github-connection` | Yes | Link GitHub App installation to workspace (owner only) |
| POST | `/api/workspace/automation/github-connection/sync` | Yes | Refresh repository targets from connected GitHub installation (owner only) |
| DELETE | `/api/workspace/automation/github-connection` | Yes | Unlink GitHub App installation from workspace (owner only) |
| GET | `/api/workspace/members` | Yes | List active workspace users |
| GET | `/api/workspace/members/:id` | Yes | Get workspace user |
| POST | `/api/workspace/members` | Yes | Create workspace user (owner only) |
| PATCH/PUT | `/api/workspace/members/:id` | Yes | Update workspace user (owner only) |
| DELETE | `/api/workspace/members/:id` | Yes | Soft-delete workspace user (owner only) |
| GET | `/api/projects/:project_id/members` | Yes | List project members (owner only) |
| POST | `/api/projects/:project_id/members` | Yes | Add project member (owner only) |
| DELETE | `/api/projects/:project_id/members/:id` | Yes | Remove project member (owner only, `:id` is user id) |
| GET | `/api/item-members/:item_type/:item_id` | Yes | List non-project item members |
| POST | `/api/item-members/:item_type/:item_id` | Yes | Add non-project item member |
| DELETE | `/api/item-members/:item_type/:item_id/:user_id` | Yes | Remove non-project item member |

## PUT `/api/workspace`

- Auth + authorization: owner only (`manage_workspace_members` permission)
- Request body:

```json
{
  "workspace": {
    "name": "New Name",
    "slug": "new-slug",
    "logo": "https://..."
  }
}
```

- Response `200`:

```json
{
  "workspace": "WorkspaceSummary"
}
```

- Errors:
  - `403` forbidden
  - `422` workspace validation errors

## Workspace automation settings

### GET `/api/workspace/automation`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Returns automation configuration plus allowed repository targets.
- Response `200`:

```json
{
  "automation": "WorkspaceAutomationSettings"
}
```

### PUT `/api/workspace/automation`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Request body:

```json
{
  "automation": {
    "provider": "codex",
    "github_app_installation_id": "123456",
    "autonomous_execution_enabled": true,
    "auto_open_prs": true,
    "codex_api_key": "sk-...",
    "clear_codex_api_key": false
  }
}
```

- Notes:
  - Sprite execution infrastructure is internal and intentionally not user-configurable.
  - `codex_api_key` is optional; when present it is encrypted at rest and marks auth method as `api_key`.
  - `clear_codex_api_key=true` removes the stored key.
  - `codex_auth_method`, `codex_oauth_account_id`, and `codex_oauth_plan_type` are response fields and are not accepted as manual update inputs.
  - Repository targets are managed via GitHub installation sync and returned as read-only in this payload.
- Response `200`: `{"automation": "WorkspaceAutomationSettings"}`
- Errors:
  - `403` forbidden
  - `422` validation errors

### GET `/api/workspace/automation/codex-connection`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Returns current Codex credential state and a user-scoped ChatGPT OAuth connect URL (when configured).
- Response `200`:

```json
{
  "codex_connection": {
    "provider": "codex",
    "status": "connected|not_connected",
    "connected": true,
    "auth_method": "api_key|chatgpt_oauth|null",
    "connect_url": "https://auth.openai.com/oauth/authorize?...|null",
    "key_last4": "string|null",
    "key_updated_at": "datetime|null",
    "oauth_account_id": "string|null",
    "oauth_plan_type": "string|null"
  }
}
```

- Notes:
  - `connect_url` is generated per user and includes a short-lived signed state token.
  - When connected through OAuth, MissionSpace stores an OAuth-derived Codex credential and exposes best-effort account metadata.

### PUT `/api/workspace/automation/codex-connection`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Request body:

```json
{
  "code": "oauth-authorization-code",
  "state": "encrypted-state-token"
}
```

- Notes:
  - `state` must match current workspace + owner and expires after `15` minutes by default.
  - Exchanges OAuth `code` for a Codex-usable credential and stores it encrypted at rest.
  - Successful linking sets `codex_auth_method` to `chatgpt_oauth`.
- Response `200`: `{"automation": "WorkspaceAutomationSettings"}`
- Errors:
  - `403` forbidden
  - `422` invalid/expired state, OAuth exchange failure, or missing usable credential

### DELETE `/api/workspace/automation/codex-connection`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Removes stored Codex credentials regardless of source (`api_key` or `chatgpt_oauth`).
- Response `200`: `{"automation": "WorkspaceAutomationSettings"}`

### POST `/api/workspace/automation/codex-connection/device`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Starts ChatGPT device authorization for Codex connection.
- Response `200`:

```json
{
  "codex_device_authorization": {
    "device_auth_id": "string",
    "user_code": "string",
    "interval_seconds": 5,
    "expires_at": "datetime|null",
    "verification_url": "https://auth.openai.com/codex/device"
  }
}
```

### POST `/api/workspace/automation/codex-connection/device/complete`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Request body:

```json
{
  "device_auth_id": "string",
  "user_code": "string"
}
```

- Response `202` while pending:

```json
{
  "codex_device_authorization": {
    "status": "pending",
    "interval_seconds": 5
  }
}
```

- Response `200` when complete: `{"automation": "WorkspaceAutomationSettings"}`

### GET `/api/workspace/automation/github-connection`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Returns current GitHub App connection state and a pre-signed connect URL (when configured).
- Response `200`:

```json
{
  "github_connection": {
    "provider": "github_app",
    "status": "connected|not_connected",
    "connected": true,
    "installation_id": "123456|null",
    "connect_url": "https://github.com/apps/.../installations/new?state=...|null",
    "repository_count": 3,
    "account_login": "octocat|null",
    "account_type": "User|Organization|null",
    "account_avatar_url": "https://avatars.githubusercontent.com/u/...|null",
    "account_url": "https://github.com/octocat|null",
    "app_slug": "missionspace-bot|null",
    "repository_selection": "all|selected|null"
  }
}
```

- Notes:
  - Account metadata is best-effort and may be `null` when GitHub metadata calls fail.
  - `repository_count` reflects currently saved repository targets in workspace automation settings.

### PUT `/api/workspace/automation/github-connection`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Request body:

```json
{
  "installation_id": "123456",
  "state": "signed-state-token"
}
```

- Notes:
  - `state` must match the current owner + workspace and expires after 15 minutes.
  - On successful link, MissionSpace attempts to sync repository targets from the GitHub installation automatically.
- Response `200`: `{"automation": "WorkspaceAutomationSettings"}`
- Errors:
  - `403` forbidden
  - `422` invalid or expired state / invalid installation id

### POST `/api/workspace/automation/github-connection/sync`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Refreshes repository targets from the currently connected GitHub App installation.
- Response `200`: `{"automation": "WorkspaceAutomationSettings"}`
- Errors:
  - `403` forbidden
  - `422` when GitHub connection is missing or server GitHub credentials are not configured

### DELETE `/api/workspace/automation/github-connection`

- Auth + authorization: owner only (`manage_workspace_automation` permission)
- Disconnects the GitHub App installation (server-side uninstall request) and removes linked installation id from workspace automation settings.
- Clears synced repository targets from workspace automation settings.
- Response `200`: `{"automation": "WorkspaceAutomationSettings"}`

## Workspace members

### GET `/api/workspace/members`

- Returns active users in current workspace.
- Response `200`: `{"data":[WorkspaceMember...]}`

### GET `/api/workspace/members/:id`

- Returns single workspace user.
- Response `200`: `{"data": WorkspaceMember}`
- Errors: `404` if user is outside current workspace or does not exist

### POST `/api/workspace/members`

- Auth + authorization: owner only
- Request body (top-level):

```json
{
  "name": "New User",
  "email": "new@example.com",
  "password": "password123",
  "role": "member",
  "timezone": "Asia/Kolkata"
}
```

- Notes:
  - `workspace_id` is injected from current session.
  - Roles allowed: `owner`, `member`, `guest`.
- Response `201`: `{"data": WorkspaceMember}`
- Errors: `403`, `422`

### PATCH/PUT `/api/workspace/members/:id`

- Auth + authorization: owner only
- Request body: top-level fields accepted by user changeset (`name`, `email`, `avatar`, `timezone`, `role`, `online`, `is_active`, etc.)
- Role change behavior:
  - Existing API keys under that user are automatically adjusted.
  - Any scopes no longer allowed by the new role are removed.
  - Scopes still allowed by the new role are preserved.
- Response `200`: `{"data": WorkspaceMember}`
- Errors: `403`, `404`, `422`

### DELETE `/api/workspace/members/:id`

- Auth + authorization: owner only
- Behavior:
  - Soft-deletes user (`is_active=false`, `deleted_at` set)
  - Scrubs email (`deleted_<id>@deleted.local`)
  - Removes project memberships, item memberships, notifications, subscriptions
  - Removes all API keys for the deleted user
- Response `204` empty body
- Errors: `403`, `404`

## Project members

### GET `/api/projects/:project_id/members`

- Owner only.
- Response `200`: `{"data":[ProjectMember...]}`

### POST `/api/projects/:project_id/members`

- Owner only.
- Request body:

```json
{
  "user_id": "uuid"
}
```

- Behavior:
  - Validates user belongs to workspace.
  - Enforces guest limit: guest can only have one project-or-item membership total.
- Response `201`: `{"data": ProjectMember}`
- Errors:
  - `403` forbidden
  - `404` project/user not found
  - `422` duplicate membership or guest-limit violation

### DELETE `/api/projects/:project_id/members/:id`

- Owner only.
- `:id` is `user_id`, not membership id.
- Response `204` empty body
- Errors: `403`, `404`

## Item members (non-project items)

Supports item types:

- `list`
- `doc_folder`
- `channel`

Important constraints:

- If the item belongs to a project, API returns `422` and instructs using project membership instead.
- Owners can manage any item members.
- Non-owners can manage members only on their own **shared** items.
- Guest limit also applies here.

### GET `/api/item-members/:item_type/:item_id`

- Response `200`: `{"data":[ItemMember...]}`
- Errors: `403`, `404`, `422` (if item belongs to project)

### POST `/api/item-members/:item_type/:item_id`

- Request body:

```json
{
  "user_id": "uuid"
}
```

- Response `201`: `{"data": ItemMember}`
- Errors: `403`, `404`, `422`

### DELETE `/api/item-members/:item_type/:item_id/:user_id`

- Response `204` empty body
- Errors: `403`, `404`, `422`
