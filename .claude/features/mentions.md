# Feature: @Mentions

## Overview

Users can mention other workspace members inside any text editor using `@Name`. When mentioned, the recipient always receives a real-time notification. Mentions work across all markdown-based content in Bridge.

## Current State

The mention system is largely implemented. This PRD documents the full feature and identifies remaining gaps.

### What Exists

| Component | Status | Notes |
|-----------|--------|-------|
| Mention autocomplete plugin | Done | `@` trigger, keyboard nav, member filtering |
| MentionList dropdown UI | Done | Shows avatar, name, email, online status |
| Markdown serialization | Done | `@[Name](member:uuid)` format |
| HTML rendering | Done | `<span class="mention" data-id data-label>@Name</span>` |
| ContentRenderer mention display | Done | Clickable mention spans |
| Backend mention extraction | Done | Parses `data-id` from HTML content |
| Notification creation | Done | Separate "mention" type, never rolled up |
| Real-time notification delivery | Done | Phoenix channels + web push |
| Auto-subscription on mention | Done | Mentioned user subscribed to item |
| Doc content editor mentions | Done | DocView passes mentions prop |
| Comment editor mentions | Done | CommentEditor in docs, tasks, channels |
| Message edit mentions | Done | Message.tsx inline editing |

### Gaps (To Implement)

| Component | Status | Notes |
|-----------|--------|-------|
| Task notes editor mentions | Missing | `RichTextNotesEditor` doesn't pass mentions prop |
| Child task notes editor mentions | Missing | Same gap in `ChildTaskDetailModal` |
| Task notes mention notification | Verify | Backend may not extract mentions on task note save |

## How It Works

### 1. Trigger & Autocomplete

- User types `@` in any text editor
- A dropdown appears listing active workspace members
- List filters as user continues typing after `@`
- Keyboard navigation: Arrow keys to select, Enter to confirm, Escape to dismiss
- Only active members of the current workspace are shown
- Member list sourced from `authStore.members`

### 2. Storage Format

Mentions are stored as markdown links:

```
@[Jane Smith](member:550e8400-e29b-41d4-a716-446655440000)
```

This format:
- Survives content sanitization
- Preserves the mention even if user is later deactivated
- Is parsed by remark into a `mention` MDAST node
- Renders as a styled `<span>` in the editor and content renderer

### 3. Rendering

In both the editor and read-only views, mentions render as:

```html
<span class="mention" data-type="mention" data-id="uuid" data-label="Jane Smith">@Jane Smith</span>
```

Styled with a distinct background color to stand out from regular text. Clickable — triggers `onMentionClick` callback (currently navigates to profile or no-op depending on context).

### 4. Notification Flow

When content containing mentions is saved:

1. **Extract**: `Bridge.Mentions.extract_mention_ids(html_content)` parses all `data-id` attributes
2. **Diff** (for edits): Compare old vs new mentions to avoid duplicate notifications
3. **Notify**: For each newly mentioned user:
   - Create a `type: "mention"` notification (never rolled up with other types)
   - Auto-subscribe the mentioned user to the item (task, doc, channel, thread)
   - Broadcast via Phoenix channel to `notifications:{user_id}`
   - Send web push notification: "@{actor_name} mentioned you in {item_name}"
4. **Self-mention**: If user mentions themselves, no notification is sent

### 5. Notification Display

- Bell icon shows unread count badge
- Mention notifications display as: **"@{Actor} mentioned you in {Item}"**
- Clicking navigates to the exact message/content via `latest_message_id`
- Mentions are always separate notifications (never grouped/rolled up)

## Scope of "Any Text Editor"

All places where users can write markdown content:

| Location | Editor Component | Mentions |
|----------|-----------------|----------|
| Doc content | RichTextEditor in DocView | Yes |
| Doc comments | CommentEditor | Yes |
| Task comments | CommentEditor | Yes |
| Task notes/description | RichTextNotesEditor in TaskDetailModal | **Gap** |
| Child task notes | RichTextNotesEditor in ChildTaskDetailModal | **Gap** |
| Channel messages | CommentEditor | Yes |
| DM messages | CommentEditor | Yes |
| Thread replies | CommentEditor | Yes |
| Message editing | RichTextEditor in Message | Yes |

## Entity Relationships

```
User (mentioner) --writes--> Content (with @mention markdown)
Content --parsed--> MentionedUser IDs
MentionedUser --receives--> Notification (type: "mention")
MentionedUser --auto-subscribed--> Item (task/doc/channel/thread)
```

## Key Decisions

1. **Workspace-scoped**: Only members of the same workspace can be mentioned
2. **Active members only**: Deactivated users don't appear in autocomplete
3. **Mention notifications never roll up**: Each mention = one notification, unlike comments which group
4. **Mentions always notify**: Regardless of subscription status — you can't opt out of being @mentioned
5. **Auto-subscribe on mention**: Being mentioned subscribes you to future activity on that item
6. **Preserved on deactivation**: Content with mentions retains the mention display even if the mentioned user is later deactivated (name stored in markdown)
7. **No self-notification**: Mentioning yourself doesn't create a notification

## Implementation Plan

### Phase 1: Close the Gaps

1. **Add mentions to RichTextNotesEditor**
   - Accept optional `mentions` prop and forward to `RichTextEditor`
   - Wire up in `TaskDetailModal` and `ChildTaskDetailModal`
   - Source members from `authStore.members`, same pattern as `CommentEditor`

2. **Verify task note save triggers mention notifications**
   - Check task update controller extracts mentions from notes field
   - If missing, add mention extraction + notification on task note update
   - Diff old vs new mentions to avoid re-notifying on edits

### Phase 2: Polish (Future)

- Mention click navigates to user profile
- @channel / @here group mentions
- Mention highlight in notification preview
- Email notification for offline users
