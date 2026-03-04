# Profile Time Zone

## Overview

Users can save their time zone in their profile settings. This prepares teammate-facing profile views to show where a person is working from (time-zone context).

## Behavior

- Time zone is an optional profile field on `users.timezone`
- Value is saved through the existing profile update endpoint: `PUT /api/auth/me`
- Time zone is returned in auth payloads (`register`, `login`, `me`, `update_me`)
- Time zone is returned in workspace member payloads (`GET /api/workspace/members`, `GET /api/workspace/members/:id`)
- Profile editor exposes a `Time zone` selector; users can leave it unset
- Time zone selector options display both IANA name and current GMT offset (for example `America/New_York (GMT-5)`)

## Data Model

- Database column: `users.timezone` (`string`, nullable)
- Intended format: IANA time zone name (for example `Europe/Berlin`)

## API Notes

- Request shape follows existing auth profile update pattern:
  - `{ user: { timezone: "America/New_York" } }`
- Frontend continues snake_case/camelCase conversion via shared API client

## Key Files

- `server/priv/repo/migrations/20260304102546_add_timezone_to_users.exs`
- `server/lib/bridge/accounts/user.ex`
- `server/lib/bridge_web/controllers/auth_controller.ex`
- `server/lib/bridge_web/controllers/workspace_member_json.ex`
- `web/src/components/features/ProfileModal.tsx`
- `web/src/stores/authStore.ts`
- `web/src/types/index.ts`
