# Multi-User Login

## Goal

Allow one device/browser to keep multiple MissionSpace accounts available and switch between them quickly, similar to Google account switching.

## Core Behavior

- A browser stores a device cookie (`ms_device`) that identifies a server-side device session.
- Each remembered account has its own device-scoped auth state and expiry.
- Remembered accounts can be either `available` or `signed_out`.
- `register`, `login`, `add-account`, and `reauth-account` issue or refresh the per-account device session.
- `GET /api/auth/accounts` returns remembered account summaries with `current` marker and `state`.
- `POST /api/auth/switch-account` switches only to `available` accounts.
- `POST /api/auth/logout` signs out the current account but keeps it on the device list as `signed_out`.
- `POST /api/auth/sign-out-account` signs out a specific remembered account without removing it.
- `DELETE /api/auth/accounts/:user_id` removes a remembered account from the device entirely.

## Limits and Safety

- Remembered accounts are device-scoped, not workspace-scoped.
- Device session state is server-side; the browser only holds the opaque device cookie.
- Account list automatically drops stale accounts (deleted/inactive/unverified/no workspace).
- Expired remembered accounts are downgraded to `signed_out` instead of disappearing.
- Switching is only allowed for remembered accounts in `available` state.

## Frontend UX

- Login page supports account chooser when remembered accounts exist.
- Users can select an `available` remembered account to sign in instantly.
- Signed-out accounts show a `Signed out` label in account lists.
- Clicking a signed-out account opens a reauth modal with the email locked to that account.
- Reauth modal includes a separate `Remove from device` path.
- Users can fall back to email/password flow via "Use another account".
- Profile menu shows switch-account options, signed-out state, per-account sign-out, remove-from-device, and add-account flows.
- Switching account triggers a full page reload to avoid stale cross-workspace in-memory state.
- Signing out the current account also reloads to the login screen to clear in-memory state.

## Key Files

- `server/lib/missionspace/accounts.ex`
- `server/lib/missionspace/accounts/device_session.ex`
- `server/lib/missionspace/accounts/device_session_account.ex`
- `server/priv/repo/migrations/20260306071814_create_device_sessions.exs`
- `server/lib/missionspace_web/controllers/auth_controller.ex`
- `server/lib/missionspace_web/router.ex`
- `server/lib/missionspace_web/plugs/auth_plug.ex`
- `server/test/missionspace_web/controllers/auth_controller_test.exs`
- `server/docs/backend-api/health-and-auth.md`
- `server/docs/backend-api/resource-schemas.md`
- `web/src/stores/authStore.ts`
- `web/src/pages/LoginPage.tsx`
- `web/src/components/features/ProfileMenu.tsx`
- `web/src/components/features/AddAccountModal.tsx`
- `web/src/components/features/AccountReauthModal.tsx`
