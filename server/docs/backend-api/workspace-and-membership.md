# Workspace and Membership APIs

## Endpoint summary

| Method | Path | Auth required | Notes |
| --- | --- | --- | --- |
| PUT | `/api/workspace` | Yes | Workspace settings update (owner only) |
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
