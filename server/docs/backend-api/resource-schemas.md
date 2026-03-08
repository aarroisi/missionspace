# Resource Schemas

This page defines the core response objects reused across endpoints.

## Auth payloads

### `AuthUser`

```json
{
  "id": "uuid",
  "name": "string",
  "email": "string",
  "avatar": "string|null",
  "timezone": "string|null",
  "role": "owner|member|guest",
  "workspace_id": "uuid"
}
```

### `WorkspaceSummary`

```json
{
  "id": "uuid",
  "name": "string",
  "slug": "string",
  "logo": "string|null"
}
```

### `RememberedAuthAccount`

```json
{
  "user": "AuthUser",
  "workspace": "WorkspaceSummary",
  "current": true,
  "state": "available|signed_out"
}
```

### `ApiKey`

```json
{
  "id": "uuid",
  "name": "string",
  "key_prefix": "msk_xxxxxxxx",
  "scopes": ["item:view", "item:create"],
  "last_used_at": "datetime|null",
  "revoked_at": "datetime|null",
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `ApiKeyVerifyResponse`

```json
{
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
```

## Common wrappers

### `ListResponse<T>`

```json
{
  "data": ["T", "..."],
  "metadata": {
    "after": "string|null",
    "before": "string|null",
    "limit": 50
  }
}
```

### `SingleResponse<T>`

```json
{
  "data": "T"
}
```

## Workspace and membership

### `WorkspaceMember`

```json
{
  "id": "uuid",
  "name": "string",
  "email": "string",
  "role": "owner|member|guest",
  "avatar": "string|null",
  "timezone": "string|null",
  "online": true,
  "is_active": true,
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `WorkspaceAutomationRepository`

```json
{
  "id": "uuid",
  "provider": "github",
  "repo_owner": "string",
  "repo_name": "string",
  "default_branch": "string",
  "enabled": true
}
```

### `WorkspaceAutomationSettings`

```json
{
  "id": "uuid",
  "provider": "codex",
  "execution_environment": "isolated",
  "github_app_installation_id": "string|null",
  "autonomous_execution_enabled": false,
  "auto_open_prs": true,
  "codex_api_key_configured": true,
  "codex_api_key_last4": "string|null",
  "codex_api_key_updated_at": "datetime|null",
  "codex_auth_method": "api_key|chatgpt_oauth|null",
  "codex_oauth_account_id": "string|null",
  "codex_oauth_plan_type": "string|null",
  "repositories": ["WorkspaceAutomationRepository"]
}
```

### `WorkspaceAutomationCodexConnection`

```json
{
  "provider": "codex",
  "status": "connected|not_connected",
  "connected": true,
  "auth_method": "api_key|chatgpt_oauth|null",
  "connect_url": "string|null",
  "key_last4": "string|null",
  "key_updated_at": "datetime|null",
  "oauth_account_id": "string|null",
  "oauth_plan_type": "string|null"
}
```

### `WorkspaceAutomationCodexDeviceAuthorization`

```json
{
  "device_auth_id": "string",
  "user_code": "string",
  "interval_seconds": 5,
  "expires_at": "datetime|null",
  "verification_url": "https://auth.openai.com/codex/device",
  "status": "pending|optional"
}
```

### `WorkspaceAutomationGitHubConnection`

```json
{
  "provider": "github_app",
  "status": "connected|not_connected",
  "connected": true,
  "installation_id": "string|null",
  "connect_url": "string|null",
  "repository_count": 3,
  "account_login": "string|null",
  "account_type": "string|null",
  "account_avatar_url": "string|null",
  "account_url": "string|null",
  "app_slug": "string|null",
  "repository_selection": "all|selected|null"
}
```

### `ProjectMember` (camelCase keys)

```json
{
  "id": "uuid",
  "userId": "uuid",
  "projectId": "uuid",
  "insertedAt": "datetime",
  "updatedAt": "datetime",
  "user": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  }
}
```

### `ItemMember`

```json
{
  "id": "uuid",
  "item_type": "list|doc_folder|channel",
  "item_id": "uuid",
  "user_id": "uuid",
  "inserted_at": "datetime",
  "user": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  }
}
```

## Project planning resources

### `Project`

```json
{
  "id": "uuid",
  "name": "string",
  "description": "string|null",
  "starred": false,
  "start_date": "date|null",
  "end_date": "date|null",
  "inserted_at": "datetime",
  "updated_at": "datetime",
  "created_by": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "items": [
    {
      "id": "uuid",
      "item_type": "board|doc_folder|channel",
      "item_id": "uuid"
    }
  ]
}
```

### `ProjectItem`

```json
{
  "id": "uuid",
  "project_id": "uuid",
  "item_type": "board|doc_folder|channel",
  "item_id": "uuid",
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `Board` (List)

```json
{
  "id": "uuid",
  "name": "string",
  "prefix": "2-5 uppercase letters",
  "visibility": "private|shared",
  "starred": false,
  "created_by_id": "uuid",
  "created_by": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "statuses": ["ListStatus"],
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `ListStatus`

```json
{
  "id": "uuid",
  "name": "UPPERCASE",
  "color": "#RRGGBB",
  "position": 0,
  "is_done": false,
  "list_id": "uuid",
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `Task`

```json
{
  "id": "uuid",
  "title": "string",
  "sequence_number": 42,
  "key": "BRD-42",
  "position": 1000,
  "is_completed": false,
  "starred": false,
  "description": "string|null",
  "due_on": "date|null",
  "completed_at": "datetime|null",
  "board_id": "uuid",
  "parent_id": "uuid|null",
  "status_id": "uuid",
  "assignee_id": "uuid|null",
  "assignee": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "created_by_id": "uuid",
  "created_by": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "status": {
    "id": "uuid",
    "name": "UPPERCASE",
    "color": "#RRGGBB",
    "position": 0,
    "is_done": false
  },
  "parent": {
    "id": "uuid",
    "title": "string",
    "board_id": "uuid"
  },
  "child_count": 0,
  "child_done_count": 0,
  "comment_count": 0,
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

## Docs resources

### `DocFolder`

```json
{
  "id": "uuid",
  "name": "string",
  "prefix": "2-5 uppercase letters",
  "visibility": "private|shared",
  "starred": false,
  "created_by_id": "uuid",
  "created_by": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `Doc`

```json
{
  "id": "uuid",
  "title": "string",
  "content": "string",
  "starred": false,
  "doc_folder_id": "uuid",
  "sequence_number": 42,
  "key": "DOC-42",
  "created_by": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "inserted_at": "iso8601",
  "updated_at": "iso8601"
}
```

## Chat resources

### `Channel`

```json
{
  "id": "uuid",
  "name": "string",
  "visibility": "private|shared",
  "starred": false,
  "created_by_id": "uuid",
  "created_by": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `DirectMessage`

```json
{
  "id": "uuid",
  "starred": false,
  "user1_id": "uuid",
  "user2_id": "uuid",
  "user1": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "user2": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `Message`

```json
{
  "id": "uuid",
  "text": "string",
  "entity_type": "task|doc|channel|dm",
  "entity_id": "uuid",
  "user_id": "uuid",
  "user_name": "string|null",
  "avatar": "string|null",
  "parent_id": "uuid|null",
  "quote_id": "uuid|null",
  "quote": {
    "id": "uuid",
    "text": "string",
    "user_name": "string|null",
    "inserted_at": "datetime"
  },
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

## Cross-cutting resources

### `Notification`

```json
{
  "id": "uuid",
  "type": "mention|comment|thread_reply",
  "item_type": "task|doc|channel|dm",
  "item_id": "uuid",
  "thread_id": "uuid|null",
  "latest_message_id": "uuid|null",
  "event_count": 1,
  "entity_type": "string|null",
  "entity_id": "uuid|null",
  "context": {},
  "read": false,
  "user_id": "uuid",
  "actor_id": "uuid",
  "actor_name": "string|null",
  "actor_avatar": "string|null",
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `Subscription`

```json
{
  "id": "uuid",
  "item_type": "task|doc|channel|dm|thread",
  "item_id": "uuid",
  "user_id": "uuid",
  "user": {
    "id": "uuid",
    "name": "string",
    "email": "string",
    "avatar": "string|null"
  },
  "inserted_at": "datetime"
}
```

### `SearchResult`

```json
{
  "data": {
    "projects": [],
    "boards": [],
    "tasks": [],
    "doc_folders": [],
    "docs": [],
    "channels": [],
    "members": []
  }
}
```

## Assets resources

### `AssetUploadRequestResponse`

```json
{
  "data": {
    "id": "uuid",
    "upload_url": "https://...",
    "storage_key": "string"
  }
}
```

### `Asset`

```json
{
  "id": "uuid",
  "filename": "string",
  "content_type": "string",
  "size_bytes": 123,
  "asset_type": "avatar|file",
  "status": "pending|active",
  "uploaded_by_id": "uuid",
  "url": "https://...|null",
  "inserted_at": "datetime",
  "updated_at": "datetime"
}
```

### `StorageUsage`

```json
{
  "data": {
    "used_bytes": 0,
    "quota_bytes": 5368709120,
    "available_bytes": 5368709120
  }
}
```
