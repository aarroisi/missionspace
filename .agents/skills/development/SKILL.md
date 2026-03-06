---
name: development
description: Development workflow, commands, and project structure for Missionspace. Use when setting up the project, running servers, or navigating the monorepo.
---

# Missionspace Development Workflow

## Project Structure

This is a **monorepo** containing multiple projects:

```
missionspace/
├── server/          # Elixir/Phoenix backend API
│   ├── lib/
│   │   ├── missionspace/           # Context modules (business logic)
│   │   └── missionspace_web/       # Controllers, channels, views
│   ├── test/                 # Backend tests
│   ├── mix.exs              # Elixir dependencies
│   └── config/              # Backend configuration
│
├── web/             # React/TypeScript frontend
│   ├── src/
│   │   ├── components/      # React components
│   │   ├── pages/           # Page components
│   │   ├── stores/          # Zustand state management
│   │   └── lib/             # Utilities
│   ├── package.json         # Node dependencies
│   └── vite.config.ts       # Vite configuration
│
└── .codex/         # AI assistant configuration
```

## Working with Multiple Projects

**IMPORTANT**: When making changes, be aware of which project you're in:

```bash
# Backend (Elixir/Phoenix)
cd server/
mix phx.server          # Start backend server (port 4000)
mix test                # Run backend tests
mix format              # Format Elixir code

# Frontend (React/TypeScript)
cd web/
npm run dev             # Start frontend dev server (port 5173)
npm test                # Run frontend tests
npm run build           # Build for production
npm run lint            # Lint TypeScript/React code
```

## Default Behavior

- When asked to "run the server" → Start backend: `cd server && mix phx.server`
- When asked to "run tests" → Run backend tests: `cd server && mix test`
- When working on controllers, contexts, schemas → Work in `server/`
- When working on components, pages, UI → Work in `web/`
- When in doubt about which project, **ASK THE USER** for clarification

## Technology Stack

### Backend (server/)

- Elixir 1.16+
- Phoenix 1.8
- Ecto (PostgreSQL ORM)
- Phoenix Channels (WebSockets)
- UUIDv7 (time-sortable UUIDs)
- ExMachina + Faker (testing)

### Frontend (web/)

- React 18
- TypeScript
- Vite (build tool)
- Zustand (state management)
- TanStack Query (data fetching)
- Tailwind CSS (styling)
- Playwright (E2E testing)

## Useful Commands

### Backend Commands

```bash
# Server
cd server && mix phx.server

# Database
mix ecto.create        # Create database
mix ecto.migrate       # Run migrations
mix ecto.rollback      # Rollback last migration
mix ecto.reset         # Drop, create, and migrate

# Tests
mix test               # Run all tests
mix test --trace       # Run with detailed output
mix coveralls          # Run with coverage report

# Code Quality
mix format             # Format code
mix credo              # Static analysis
mix dialyzer           # Type checking
```

### Frontend Commands

```bash
# Development
cd web && npm run dev

# Testing
npm test               # Run unit tests
npm run test:e2e       # Run E2E tests with Playwright
npx playwright test    # Run Playwright tests directly

# Build
npm run build          # Production build
npm run preview        # Preview production build

# Code Quality
npm run lint           # Lint TypeScript/React
npm run format         # Format code with Prettier
```

## Project Overview

Missionspace is a team collaboration platform built with:

- **Backend**: Elixir/Phoenix (server/)
- **Frontend**: React/TypeScript with Vite (web/)
- **Database**: PostgreSQL
- **Real-time**: Phoenix Channels for WebSocket communication
