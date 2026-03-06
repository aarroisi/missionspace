# Missionspace Backend API Docs

This documentation covers every backend API currently exposed by the server:

- HTTP routes in `lib/missionspace_web/router.ex`
- WebSocket channels in `lib/missionspace_web/channels/*.ex`
- Transport endpoints in `lib/missionspace_web/endpoint.ex`

These pages are written for agents and automation, not marketing docs.

## Read this first

1. [HTTP Conventions](./http-conventions.md)
2. [Resource Schemas](./resource-schemas.md)

## Table of contents

- [Health and Auth APIs](./health-and-auth.md)
- [Workspace and Membership APIs](./workspace-and-membership.md)
- [Projects, Boards, and Tasks APIs](./projects-boards-tasks.md)
- [Doc Folders and Docs APIs](./docs-and-doc-folders.md)
- [Chat and Messaging APIs](./chat-and-messaging.md)
- [Search, Stars, Subscriptions, Notifications, Push APIs](./search-stars-subscriptions-notifications-push.md)
- [Assets and Storage APIs](./assets-and-storage.md)
- [Realtime WebSocket APIs](./realtime-websocket.md)
- [Dev and Framework Endpoints](./dev-and-framework-endpoints.md)

## Source of truth

- Route inventory command: `mix phx.routes`
- HTTP route definition: `lib/missionspace_web/router.ex`
- Socket transports: `lib/missionspace_web/endpoint.ex`
- Channel topics and events: `lib/missionspace_web/channels/*.ex`

If generated docs and source disagree, source code wins.
