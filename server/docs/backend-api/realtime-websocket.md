# Realtime WebSocket APIs

## Transport endpoints

| Transport | Path | Auth model |
| --- | --- | --- |
| Phoenix Socket | `/socket/websocket` | Phoenix auth token |
| Phoenix LiveView Socket | `/live/websocket` | LiveView session transport |

Primary realtime API for app features is `/socket/websocket` with `MissionspaceWeb.UserSocket`.

## Socket auth (`MissionspaceWeb.UserSocket`)

- Browser clients must connect with the Phoenix channel auth token returned by login-style auth responses such as `POST /api/auth/login`, `GET /api/auth/me`, `POST /api/auth/switch-account`, and `POST /api/auth/reauth-account`.
- The endpoint enables Phoenix `auth_token` transport support, so JavaScript clients should pass the token via the socket client's `authToken` option.
- Server verifies the token with salt `"user socket"` and max age `1209600` seconds.
- On success: assigns both `user_id` and `workspace_id` on the socket.
- If production frontend and API live on different subdomains, `check_origin` must allow the frontend origin (for example `https://missionspace.co`).

## Registered channel topics

| Topic pattern | Module |
| --- | --- |
| `list:*` | `MissionspaceWeb.ListChannel` |
| `task:*` | `MissionspaceWeb.TaskChannel` |
| `doc:*` | `MissionspaceWeb.DocChannel` |
| `channel:*` | `MissionspaceWeb.ChatChannel` |
| `dm:*` | `MissionspaceWeb.ChatChannel` |
| `notifications:*` | `MissionspaceWeb.NotificationChannel` |

## `list:<list_id>` (`MissionspaceWeb.ListChannel`)

### Join

- Validates list exists in current workspace.
- On success: assigns `list_id`.

### Client -> server events

| Event | Payload |
| --- | --- |
| `new_task` | `{ "task": { ...task fields... } }` |
| `update_task` | `{ "task_id": "uuid", "updates": { ... } }` |
| `delete_task` | `{ "task_id": "uuid" }` |

### Server broadcasts

| Event | Payload |
| --- | --- |
| `task_created` | `{ "task": Task }` |
| `task_updated` | `{ "task": Task }` |
| `task_deleted` | `{ "task_id": "uuid" }` |

## `task:<task_id>` (`MissionspaceWeb.TaskChannel`)

### Join

- Validates task exists.
- On success: assigns `task_id`.

### Client -> server events

| Event | Payload |
| --- | --- |
| `update_status` | `{ "status": "..." }` |
| `update_task` | `{ "updates": { ...task fields... } }` |
| `new_comment` | `{ "text": "string" }` |
| `assign_user` | `{ "user_id": "uuid" }` |

### Server broadcasts

| Event | Payload |
| --- | --- |
| `status_updated` | `{ "task_id": "uuid", "status": "...", "task": Task }` |
| `task_updated` | `{ "task": Task }` |
| `comment_added` | `{ "comment": Message, "task_id": "uuid" }` |
| `user_assigned` | `{ "task_id": "uuid", "assignee": User, "task": Task }` |

## `doc:<doc_id>` (`MissionspaceWeb.DocChannel`)

### Join

- Validates doc exists in current workspace.
- On success: assigns `doc_id`.

### Client -> server events

| Event | Payload |
| --- | --- |
| `update_content` | `{ "content": "markdown" }` |
| `update_title` | `{ "title": "string" }` |
| `new_comment` | `{ "text": "string" }` |
| `cursor_position` | `{ "position": ... }` |
| `toggle_starred` | `{}` |

### Server broadcasts

| Event | Payload |
| --- | --- |
| `content_updated` | `{ "doc_id": "uuid", "content": "...", "updated_by": "user_id", "doc": Doc }` |
| `title_updated` | `{ "doc_id": "uuid", "title": "...", "doc": Doc }` |
| `comment_added` | `{ "comment": Message, "doc_id": "uuid" }` |
| `cursor_moved` | `{ "user_id": "uuid", "position": ..., "doc_id": "uuid" }` |

## `channel:<channel_id>` and `dm:<dm_id>` (`MissionspaceWeb.ChatChannel`)

### Join

- `channel:<id>`:
  - validates channel exists in current workspace.
  - assigns `channel_id`, `room_type="channel"`.
- `dm:<id>`:
  - validates DM exists in workspace.
  - requires current user to be `user1` or `user2`.
  - assigns `dm_id`, `room_type="dm"`.
- After join:
  - tracks Phoenix Presence.
  - pushes `presence_state` to client.

### Client -> server events

| Event | Payload |
| --- | --- |
| `new_message` | `{ "text": "...", "parent_id": "optional", "quote_id": "optional" }` |
| `delete_message` | `{ "message_id": "uuid" }` |
| `update_message` | `{ "message_id": "uuid", "text": "..." }` |
| `typing_start` | `{}` |
| `typing_stop` | `{}` |

### Server broadcasts

| Event | Payload |
| --- | --- |
| `new_message` | `{ "message": Message }` |
| `message_deleted` | `{ "message_id": "uuid" }` |
| `message_updated` | `{ "message": Message }` |
| `user_typing` | `{ "user_id": "uuid", "typing": true|false }` |
| `presence_state` | Phoenix Presence state |
| `presence_diff` | Phoenix Presence diff |

## `notifications:<user_id>` (`MissionspaceWeb.NotificationChannel`)

### Join

- Only allows user to join topic matching their own `user_id`.

### Server broadcasts

- Event: `new_notification`
- Trigger helper: `MissionspaceWeb.NotificationChannel.broadcast_notification(user_id, payload)`
