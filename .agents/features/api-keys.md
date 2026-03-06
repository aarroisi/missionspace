# API Keys

## Goal

Add user-scoped API keys with scope-based authorization so users can automate API access safely.

## Core behavior

- API keys are attached to a user, not directly to a workspace.
- Workspace context is resolved from the attached user.
- API key scopes are always capped by the attached user's role scopes.
- Non-API-key requests keep using role scopes.

## Scope model

- Scope catalog lives in `server/lib/missionspace/authorization/scopes.ex`.
- Authorization flow is now:
  1. Check required scope for action.
  2. If scope is present, run resource-level policy checks.

## API key lifecycle

### Create

- Endpoint: `POST /api/api-keys`
- Input: `name`, optional `scopes`
- If `scopes` omitted, defaults to full role scopes.
- Plaintext key is returned once in create response only.
- Stored values: key hash + key prefix + scopes.

### List

- Endpoint: `GET /api/api-keys`
- Returns active (non-revoked) keys for current user.

### Revoke

- Endpoint: `DELETE /api/api-keys/:id`
- Revokes key if owned by current user.

### Verify

- Endpoint: `GET /api/api-keys/verify`
- Auth via `X-API-Key` or `Authorization: Bearer msk_...`
- Returns validity, key metadata, user metadata, and effective scopes.

## Role change and deletion behavior

- When a user's role changes, all active API keys for that user are reconciled:
  - Remove scopes no longer permitted.
  - Keep scopes still permitted.
- When a user is soft-deleted, all their API keys are removed.

## Frontend behavior

- API key management UI is in profile modal.
- User can:
  - Create key (name + scope selection)
  - Copy key
  - Verify newly created key immediately
  - Revoke existing keys
- Newly created key is shown once with explicit warning.
