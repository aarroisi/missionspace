# Bridge Project

Bridge is a team collaboration platform: Elixir/Phoenix backend + React/TypeScript frontend.

## Quick Reference

```bash
# Backend (port 4000)           # Frontend (port 5173)
cd server && mix phx.server     cd web && npm run dev

# Tests
cd server && mix test           cd web && npx playwright test
```

## Critical Rules

1. **Workspace Isolation**: Always filter by `workspace_id` - prevents data leakage
2. **Tuple Returns**: Use `{:ok, result}` / `{:error, reason}` - never bang functions
3. **Test-Driven**: Always use TDD for both backend and frontend - write tests first, then implement
4. **E2E Testing**: Use `keyboard.insertText()` for React inputs, NOT `fill()`
5. **Toast Notifications**: Always show toast after successful backend mutations (create, update, delete) using `useToastStore`
6. **API Params**: Send params directly without nested wrappers - use `{name, email}` NOT `{user: {name, email}}`
7. **Product Spec First**: All product decisions must be documented in `.codex/skills/product/SKILL.md`. When a discussion hints at product behavior or business rules:
   - **Update** the spec if it's a new decision
   - **Debate** if it conflicts with existing spec - don't silently override
   - This keeps decisions aligned and auditable
8. **Feature Specs**: Every new feature must have a specification file in `.codex/features/`. When implementing a new feature:
   - Create a markdown file named after the feature (e.g., `.codex/features/search.md`, `.codex/features/subscriptions.md`)
   - Document: what it does, how it works, key decisions, entity relationships, and UI behavior
   - Update the spec as the feature evolves — changes are tracked in git alongside the code
   - This makes it easy to generate product docs later
9. **Destructive Actions Need Confirmation**: Any destructive UI action (delete, revoke, remove, disconnect, etc.) must use the shared `ConfirmModal` pattern before executing.

## Documentation

Detailed guides organized as skills in `.codex/skills/`:

- `/development` - Project structure, commands, monorepo navigation
- `/architecture` - Patterns: error handling, controllers, multi-tenancy, UUIDs, pagination
- `/testing` - TDD practices, factories, meaningful tests
- `/e2e-testing` - Playwright + React gotchas (controlled inputs)
- `/product` - Product specification and business rules (data ownership, user management, permissions)

Background skills (auto-loaded by context):

- `backend` - Elixir/Phoenix patterns when in `server/`
- `frontend` - React/TypeScript patterns when in `web/`
- `product` - Business rules when implementing features involving data ownership or user management

## Tech Stack

**Backend**: Elixir 1.16+, Phoenix 1.8, PostgreSQL, Phoenix Channels  
**Frontend**: React 18, TypeScript, Vite, Zustand, Tailwind, Playwright
