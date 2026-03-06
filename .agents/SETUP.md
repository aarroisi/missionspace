# Missionspace Setup Guide

This guide will help you get Missionspace up and running on your local machine.

## Prerequisites Check

Before starting, ensure you have:

- ✅ Elixir 1.18+ installed (`elixir --version`)
- ✅ Erlang/OTP 27 installed
- ✅ Node.js 18+ installed (`node --version`)
- ✅ PostgreSQL 14+ installed and running
- ✅ npm or yarn installed

## Quick Start

### Step 1: Fix npm Cache (if needed)

If you encounter npm permission errors, run:

```bash
sudo chown -R $(id -u):$(id -g) "$HOME/.npm"
```

### Step 2: Backend Setup

```bash
cd server

# Install dependencies
mix deps.get

# Setup database (creates DB, runs migrations, seeds data)
mix ecto.setup

# Start the server
mix phx.server
```

The backend will be available at:

- API: http://localhost:4000/api
- WebSocket: ws://localhost:4000/socket

### Step 3: Frontend Setup

```bash
cd web

# Install dependencies
npm install

# Start development server
npm run dev
```

The frontend will be available at http://localhost:5173

## Verification

### Test Backend

```bash
# In another terminal
curl http://localhost:4000/api/projects

# Should return JSON with sample projects
```

### Test Frontend

Open http://localhost:5173 in your browser. You should see:

- Outer sidebar with 6 icons (Home, Projects, Lists, Docs, Channels, DMs)
- Inner sidebar showing items based on selected category
- Main content area

## Sample Data

The seed file creates:

**Users:**

- Alex Kim (alex@missionspace.app)
- Morgan Jones (morgan@missionspace.app)
- Sam Rivera (sam@missionspace.app)

**Projects:**

- Product Launch (starred)
- Website Redesign

**Lists:**

- Sprint Tasks (with 3 tasks)
- Design Tasks

**Sample Tasks:**

- "Design new homepage" (in progress, assigned to Alex)
- "Implement authentication" (todo)
- "Write user documentation" (done, assigned to Sam)

**Docs:**

- Product Requirements
- Design System

**Channels:**

- #general (starred)
- #design

## Common Issues

### Database Connection Error

```bash
# Check PostgreSQL is running
pg_ctl status

# Or with Homebrew
brew services list

# Start if needed
brew services start postgresql
```

### Port Already in Use

**Backend (Port 4000):**

```bash
lsof -ti:4000 | xargs kill -9
```

**Frontend (Port 5173):**

```bash
lsof -ti:5173 | xargs kill -9
```

### Mix Command Not Found

```bash
# Install Elixir
brew install elixir

# Install Hex package manager
mix local.hex --force

# Install Phoenix
mix archive.install hex phx_new --force
```

### npm Permission Errors

```bash
# Fix npm cache permissions
sudo chown -R $(id -u):$(id -g) "$HOME/.npm"

# Or use different cache location
npm install --cache ~/.npm-temp
```

### Database Doesn't Exist

```bash
cd server
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

## Development Workflow

### Backend Changes

1. Edit files in `server/lib/missionspace/` or `server/lib/missionspace_web/`
2. Phoenix automatically recompiles on save
3. For new dependencies: `mix deps.get`
4. For database changes: `mix ecto.gen.migration name` then `mix ecto.migrate`

### Frontend Changes

1. Edit files in `web/src/`
2. Vite hot-reloads automatically
3. For new dependencies: `npm install package-name`
4. Type checking: `npm run typecheck`

### Database Reset

```bash
cd server
mix ecto.reset  # Drops, creates, migrates, and seeds
```

## Testing the App

### Test Lists Feature

1. Click "Lists" in outer sidebar
2. Select "Sprint Tasks" from inner sidebar
3. View tasks in board view (default)
4. Click a task to see details panel
5. Add a comment
6. Check/uncheck subtasks

### Test Docs Feature

1. Click "Docs" in outer sidebar
2. Select "Product Requirements"
3. Click to edit content
4. Use toolbar to format text
5. Add a comment below

### Test Chat Feature

1. Click "Channels" in outer sidebar
2. Select "#general"
3. Type and send a message
4. Click "Reply" on a message to start a thread
5. Click "Quote" to reference a message

### Test Real-time Updates

1. Open app in two browser windows
2. Make changes in one window (e.g., update task status)
3. See updates appear instantly in the other window

## Next Steps

1. **Customize** - Edit colors in `web/tailwind.config.js`
2. **Add Features** - Create new contexts, controllers, and components
3. **Deploy** - See README.md for deployment instructions
4. **Learn** - Check .codex/AGENTS.md for development conventions

## Useful Commands

### Backend

```bash
# Interactive shell
iex -S mix phx.server

# Run tests
mix test

# Format code
mix format

# View routes
mix phx.routes

# Generate migration
mix ecto.gen.migration migration_name
```

### Frontend

```bash
# Build for production
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint

# Type check
npm run typecheck
```

## Getting Help

- Check the main README.md for API documentation
- See .codex/AGENTS.md for code conventions
- Check the Phoenix docs: https://hexdocs.pm/phoenix
- Check the React docs: https://react.dev

---

Happy coding! 🚀
