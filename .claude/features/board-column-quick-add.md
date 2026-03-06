# Board Column Quick Add

## Overview

Board view gets a first-class `Add Column` flow so users can create statuses without opening `Manage Statuses`.

This flow is optimized for fast creation (name + color) while keeping advanced operations (rename existing statuses, delete, reorder) in Status Manager.

## Scope

- Add `Add Column` action in board header on desktop.
- Add `Add Column` action in mobile board actions menu.
- Open a lightweight modal with:
  - status name input
  - status color selector (same palette as Status Manager)
  - create/cancel actions
- Reuse existing status APIs (`POST /api/boards/:id/statuses`) through frontend store.

## Out of Scope

- No database or schema changes.
- No new status management capabilities beyond quick create.
- No changes to drag-and-drop task behavior.

## User Behavior

### Desktop

- User clicks `Add Column` in board header.
- Modal opens immediately.
- User enters name, optionally changes color, and submits.
- Modal closes on success.
- New column appears in board view immediately.

### Mobile

- User taps board actions menu (`...`).
- User taps `Add Column`.
- Same modal opens.
- Flow and success behavior match desktop.

## Validation and Errors

- Name is required.
- Duplicate names in the same board are rejected (case-insensitive; backend-enforced uniqueness).
- Invalid names/colors from backend validation show clear user-facing errors.
- Validation feedback should be clear and actionable (inline in modal and/or toast).

## Business Rules

- Status names are unique per board.
- `DONE` must remain last.
  - Quick add must preserve this rule without requiring manual reorder.
  - Newly added statuses are inserted before `DONE` (existing backend behavior).

## State and API Notes

- Use `useBoardStore().createStatus(boardId, { name, color })`.
- Keep quick-add color palette shared with Status Manager from one constant source.
- Show success and error toasts via `useToastStore`.

## Acceptance Criteria

- User can launch add-column flow quickly from board header on desktop and mobile.
- New column appears immediately after creation and persists after refresh.
- `DONE` remains last after adding a column.
- Duplicate/invalid names return clear errors.
- Existing `Manage Statuses` flow remains available for advanced edits.
