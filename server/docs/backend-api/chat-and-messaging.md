# Chat and Messaging APIs

## Endpoint summary

| Method | Path | Auth required | Notes |
| --- | --- | --- | --- |
| GET | `/api/channels` | Yes | Paginated channels |
| POST | `/api/channels` | Yes | Create channel |
| GET | `/api/channels/:id` | Yes | Get channel |
| PATCH/PUT | `/api/channels/:id` | Yes | Update channel |
| DELETE | `/api/channels/:id` | Yes | Delete channel |
| GET | `/api/direct_messages` | Yes | Paginated DMs for current user |
| POST | `/api/direct_messages` | Yes | Create/get DM with another user |
| GET | `/api/direct_messages/:id` | Yes | Get DM (participants only) |
| PATCH/PUT | `/api/direct_messages/:id` | Yes | Update DM |
| DELETE | `/api/direct_messages/:id` | Yes | Delete DM |
| GET | `/api/messages` | Yes | Paginated messages |
| POST | `/api/messages` | Yes | Create message |
| GET | `/api/messages/:id` | Yes | Get message |
| PATCH/PUT | `/api/messages/:id` | Yes | Update message |
| DELETE | `/api/messages/:id` | Yes | Delete message |
| GET | `/api/read-positions/unread` | Yes | Unread channel/DM ids |
| GET | `/api/read-positions/:item_type/:item_id` | Yes | Last read timestamp |
| POST | `/api/read-positions/:item_type/:item_id` | Yes | Mark as read |

## Channels

### GET `/api/channels`

- Query params: `limit`, `after`, `before`
- Response `200`: paginated `Channel[]`

### POST `/api/channels`

- Request body:

```json
{
  "name": "general",
  "visibility": "shared"
}
```

- Behavior:
  - `workspace_id` and `created_by_id` are injected.
  - Creator is auto-subscribed to the channel.
- Response `201`: `{"data": Channel}`
- Errors: `403`, `422`

### GET `/api/channels/:id`

- Response `200`: `{"data": Channel}`
- Errors: `403`, `404`

### PATCH/PUT `/api/channels/:id`

- Request body: mutable channel fields (`name`, `visibility`)
- Response `200`: `{"data": Channel}`
- Errors: `403`, `404`, `422`

### DELETE `/api/channels/:id`

- Response `204`
- Errors: `403`, `404`

## Direct messages

### GET `/api/direct_messages`

- Query params: `limit`, `after`, `before`
- Returns only conversations where current user is `user1` or `user2`.
- Response `200`: paginated `DirectMessage[]`

### POST `/api/direct_messages`

- Request body:

```json
{
  "user2_id": "uuid"
}
```

- Behavior:
  - Creates DM if missing; otherwise returns existing one (idempotent).
- Response `201`: `{"data": DirectMessage}`
- Errors: `422`

### GET `/api/direct_messages/:id`

- Access: only participants in DM.
- Response `200`: `{"data": DirectMessage}`
- Errors: `403`, `404`

### PATCH/PUT `/api/direct_messages/:id`

- Access: only participants in DM.
- Request body: passed through to DM changeset.
- Response `200`: `{"data": DirectMessage}`
- Errors: `403`, `404`, `422`

### DELETE `/api/direct_messages/:id`

- Access: only participants in DM.
- Response `204`
- Errors: `403`, `404`

## Messages

Entity types: `task`, `doc`, `channel`, `dm`.

### GET `/api/messages`

- Query params:
  - `entity_type`
  - `entity_id`
  - pagination (`limit`, `after`, `before`)
- Behavior:
  - If `entity_type` and `entity_id` present -> filtered messages.
  - Otherwise -> global paginated messages.
- Response `200`: paginated `Message[]`

### POST `/api/messages`

- Request body (top-level):

```json
{
  "text": "hello",
  "entity_type": "channel",
  "entity_id": "uuid",
  "parent_id": "optional-message-uuid",
  "quote_id": "optional-message-uuid"
}
```

- Compatibility aliases accepted:
  - `entityType` / `entity_type`
  - `entityId` / `entity_id`
  - `parentId` / `parent_id`
  - `quoteId` / `quote_id`

- Authorization behavior:
  - Validates user can comment on target entity when type/id are valid.
  - For `channel` and `dm` messages, also broadcasts `new_message` on the matching realtime room topic.
- Response `201`: `{"data": Message}`
- Errors: `403`, `422`

### GET `/api/messages/:id`

- Response `200`: `{"data": Message}`
- Errors: `404`

### PATCH/PUT `/api/messages/:id`

- Update permission: message author only.
- Request body: message fields accepted by changeset (`text`, `entity_type`, etc.)
- For `channel` and `dm` messages, also broadcasts `message_updated` on the matching realtime room topic.
- Response `200`: `{"data": Message}`
- Errors: `403`, `404`, `422`

### DELETE `/api/messages/:id`

- Delete permission: message author, or workspace owner.
- For `channel` and `dm` messages, also broadcasts `message_deleted` on the matching realtime room topic.
- Response `204`
- Errors: `403`, `404`

## Read positions (channel/dm unread state)

Valid `item_type`: `channel`, `dm`.

### GET `/api/read-positions/unread`

- Response `200`:

```json
{
  "data": {
    "channels": ["channel-id", "..."],
    "dms": ["dm-id", "..."]
  }
}
```

### GET `/api/read-positions/:item_type/:item_id`

- Response `200`:

```json
{
  "data": {
    "lastReadAt": "datetime|null"
  }
}
```

### POST `/api/read-positions/:item_type/:item_id`

- Upserts read position with current timestamp.
- Response `200`:

```json
{
  "data": {
    "status": "ok"
  }
}
```
