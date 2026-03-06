# Dev and Framework Endpoints

These are backend endpoints exposed by Phoenix runtime but not part of the core business REST API.

## Dev-only endpoints (`:dev_routes`)

When `Application.compile_env(:missionspace, :dev_routes)` is enabled:

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/dev/dashboard/css-:md5` | LiveDashboard assets |
| GET | `/dev/dashboard/js-:md5` | LiveDashboard assets |
| GET | `/dev/dashboard` | LiveDashboard home |
| GET | `/dev/dashboard/:page` | LiveDashboard page |
| GET | `/dev/dashboard/:node/:page` | LiveDashboard node page |
| * | `/dev/mailbox` | Swoosh mailbox preview |

## LiveView transport endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| WS | `/live/websocket` | Phoenix LiveView websocket |
| GET | `/live/longpoll` | LiveView longpoll fallback |
| POST | `/live/longpoll` | LiveView longpoll fallback |

## Related realtime endpoint

- `WS /socket/websocket` (documented in `realtime-websocket.md`) is the main app-specific socket API.
