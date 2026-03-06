# Missionspace - Team Collaboration App

Missionspace is a modern team collaboration app featuring Docs (rich text posts), Lists (task management), and Chat (channels/DMs). Built as a Progressive Web App with Phoenix (Elixir) backend and React frontend.

## Features

- **Projects** - Organize work into projects containing lists, docs, and channels
- **Lists** - Kanban-style task management with subtasks, assignments, and due dates
- **Docs** - Collaborative rich-text documents with real-time editing
- **Channels** - Team chat with threading and message quoting
- **Direct Messages** - Private conversations between users
- **Real-time Updates** - Phoenix Channels for instant synchronization
- **PWA** - Install as a native app on any device
- **Universal Threading** - One-level threading on all comments and messages

## Tech Stack

### Backend

- **Elixir 1.18.2** with **Phoenix 1.8.3**
- **PostgreSQL** database with Ecto
- **Phoenix Channels** for WebSocket real-time features
- **Phoenix Presence** for online status tracking

### Frontend

- **React 18.3** with **TypeScript 5.7**
- **Vite 6.0** for lightning-fast builds
- **Zustand 5.0** for state management
- **Tailwind CSS 3.4** for styling
- **Tiptap 2.10** for rich text editing
- **Phoenix.js** for WebSocket client
- **Vite PWA Plugin** for Progressive Web App features

## Project Structure

```
missionspace/
├── server/              # Phoenix backend
│   ├── lib/
│   │   ├── missionspace/              # Business logic contexts
│   │   │   ├── accounts/        # User management
│   │   │   ├── projects/        # Project schemas
│   │   │   ├── lists/           # List, Task, Subtask schemas
│   │   │   ├── docs/            # Document schemas
│   │   │   └── chat/            # Channel, DM, Message schemas
│   │   └── missionspace_web/          # Web layer
│   │       ├── controllers/     # JSON API controllers
│   │       ├── channels/        # WebSocket channels
│   │       └── endpoint.ex      # HTTP endpoint
│   ├── priv/repo/migrations/    # Database migrations
│   └── mix.exs                  # Dependencies
│
└── web/                 # React frontend
    ├── src/
    │   ├── components/
    │   │   ├── ui/              # Reusable UI components
    │   │   ├── layout/          # Layout components
    │   │   └── features/        # Feature components
    │   ├── pages/               # Route pages
    │   ├── stores/              # Zustand state stores
    │   ├── hooks/               # Custom React hooks
    │   ├── lib/                 # Utilities
    │   └── types/               # TypeScript types
    └── package.json
```

## Getting Started

### Prerequisites

- **Elixir 1.18+** and **Erlang/OTP 27**
- **Node.js 18+** and **npm**
- **PostgreSQL 14+**

### Installation

#### 1. Install Elixir and Phoenix

```bash
# macOS
brew install elixir
mix local.hex --force
mix archive.install hex phx_new --force
```

#### 2. Clone and Setup Backend

```bash
cd server

# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# This will:
# - Create the database
# - Run migrations
# - Seed with sample data
```

#### 3. Setup Frontend

```bash
cd web

# Install dependencies
npm install
```

### Running the Application

#### Start Backend (Terminal 1)

```bash
cd server
mix phx.server
```

The API will be available at `http://localhost:4000/api`  
WebSocket at `ws://localhost:4000/socket`

#### Start Frontend (Terminal 2)

```bash
cd web
npm run dev
```

The app will be available at `http://localhost:5173`

### Development Commands

#### Backend

```bash
# Start interactive shell
iex -S mix phx.server

# Run tests
mix test

# Format code
mix format

# Reset database
mix ecto.reset

# Create migration
mix ecto.gen.migration migration_name

# Check routes
mix phx.routes
```

#### Frontend

```bash
# Development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Lint
npm run lint

# Type check
npm run typecheck
```

## API Endpoints

### REST API

All endpoints are prefixed with `/api`

#### Projects

- `GET /api/projects` - List all projects
- `GET /api/projects/:id` - Get project
- `POST /api/projects` - Create project
- `PATCH /api/projects/:id` - Update project
- `DELETE /api/projects/:id` - Delete project

#### Lists

- `GET /api/lists` - List all lists
- `GET /api/lists/:id` - Get list with tasks
- `POST /api/lists` - Create list
- `PATCH /api/lists/:id` - Update list
- `DELETE /api/lists/:id` - Delete list

#### Tasks

- `GET /api/tasks` - List all tasks
- `GET /api/tasks/:id` - Get task with subtasks
- `POST /api/tasks` - Create task
- `PATCH /api/tasks/:id` - Update task
- `DELETE /api/tasks/:id` - Delete task

#### Subtasks

- `GET /api/subtasks` - List all subtasks
- `GET /api/subtasks/:id` - Get subtask
- `POST /api/subtasks` - Create subtask
- `PATCH /api/subtasks/:id` - Update subtask
- `DELETE /api/subtasks/:id` - Delete subtask

#### Docs

- `GET /api/docs` - List all docs
- `GET /api/docs/:id` - Get doc
- `POST /api/docs` - Create doc
- `PATCH /api/docs/:id` - Update doc
- `DELETE /api/docs/:id` - Delete doc

#### Channels

- `GET /api/channels` - List all channels
- `GET /api/channels/:id` - Get channel
- `POST /api/channels` - Create channel
- `PATCH /api/channels/:id` - Update channel
- `DELETE /api/channels/:id` - Delete channel

#### Direct Messages

- `GET /api/direct_messages` - List all DMs
- `GET /api/direct_messages/:id` - Get DM
- `POST /api/direct_messages` - Create DM
- `PATCH /api/direct_messages/:id` - Update DM
- `DELETE /api/direct_messages/:id` - Delete DM

#### Messages

- `GET /api/messages?entity_type=channel&entity_id=123` - List messages
- `GET /api/messages/:id` - Get message
- `POST /api/messages` - Create message
- `PATCH /api/messages/:id` - Update message
- `DELETE /api/messages/:id` - Delete message

### WebSocket Channels

Connect to `ws://localhost:4000/socket`

#### Channels

- `list:ID` - List updates (tasks created/updated/deleted)
- `task:ID` - Task updates (status, assignments, comments)
- `doc:ID` - Document updates (content, comments, cursor positions)
- `channel:ID` - Channel messages with presence
- `dm:ID` - Direct messages with presence

#### Example Events

```javascript
// Join a channel
channel
  .join()
  .receive("ok", (resp) => console.log("Joined", resp))
  .receive("error", (resp) => console.log("Failed", resp));

// Send message
channel.push("new_message", { text: "Hello!" });

// Listen for updates
channel.on("new_message", (payload) => {
  console.log("New message:", payload);
});
```

## Database Schema

### Core Tables

- **users** - User accounts with online status
- **projects** - Project containers
- **lists** - Task lists (can belong to project)
- **tasks** - Individual tasks with status, due dates, assignments
- **subtasks** - Task breakdown items
- **docs** - Rich text documents
- **channels** - Team chat channels
- **direct_messages** - Private conversations between two users
- **messages** - Universal message/comment table for all entities

### Key Relationships

- Projects → Lists, Docs, Channels (one-to-many)
- Lists → Tasks (one-to-many)
- Tasks → Subtasks (one-to-many)
- Tasks, Subtasks, Docs, Channels, DMs → Messages (polymorphic via entity_type/entity_id)
- Messages → Messages (threading via parent_id, quoting via quote_id)

## Architecture Decisions

### Real-time Strategy

All real-time features use Phoenix Channels for efficient bidirectional communication:

- Task updates broadcast to list subscribers
- Doc edits broadcast to doc subscribers (excluding sender for collaborative editing)
- Chat messages broadcast to channel/DM subscribers
- Presence tracking for online users

### State Management

- **Zustand** for global app state (entities, UI state)
- **React state** for local component state
- **URL** for navigation state

### Threading Model

- One level of threading (replies to a message)
- Any message can quote any other message
- Thread panel opens on the right sidebar
- Works universally across tasks, docs, channels, and DMs

### Two-Sidebar Layout

- **Outer sidebar (56px)** - Fixed category navigation
- **Inner sidebar (208px)** - Collapsible item lists
- **Main content** - Active view
- **Detail panel** - Task details or thread panel

## Deployment

### Backend (Production)

```bash
cd server

# Set environment variables
export DATABASE_URL="postgres://user:pass@host/missionspace_prod"
export SECRET_KEY_BASE="$(mix phx.gen.secret)"

# Build release
MIX_ENV=prod mix release

# Run migrations
_build/prod/rel/missionspace/bin/missionspace eval "Missionspace.Release.migrate"

# Start server
_build/prod/rel/missionspace/bin/missionspace start
```

### Frontend (Production)

```bash
cd web

# Build
npm run build

# Deploy dist/ folder to CDN or static host
```

## Sample Data

The seed file creates:

- 3 users (Alex Kim, Morgan Jones, Sam Rivera)
- 2 projects (Product Launch, Website Redesign)
- 2 lists with tasks and subtasks
- 2 docs
- 2 channels
- Direct messages and sample messages

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:

- GitHub Issues: https://github.com/yourusername/missionspace/issues
- Documentation: See .codex/PRD.md and .codex/AGENTS.md

---

Built with ❤️ using Phoenix and React
