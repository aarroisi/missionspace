# Missionspace — Product Requirements Document

## Executive Summary

Missionspace is a team collaboration app centered on **Docs** (rich text posts) and **Lists** (task management), with **Chat** as the connective communication layer. It combines the best of Slack's lists/canvases, Basecamp's message boards, and modern task management—without the bloat.

**Name Rationale:** Like a ship's missionspace where the captain commands and has full visibility, Missionspace is where teams steer their projects. It also represents connection—bridging people, ideas, and work artifacts together.

**Core Philosophy:**

- Content-first (Docs & Lists), chat as communication layer
- Start messy (standalone items), graduate to structured (Projects)
- Snappy, native-feel performance
- Opinionated simplicity over customization

---

## 1. Information Architecture

### 1.1 Object Types

| Type        | Icon        | Description                                             |
| ----------- | ----------- | ------------------------------------------------------- |
| **Project** | 📁 Folder   | Container that groups related Lists, Docs, and Channels |
| **List**    | ☰ Columns  | 2-level task list (Tasks → Subtasks) with fixed fields  |
| **Doc**     | 📄 FileText | Rich text post by a single author, with comments        |
| **Channel** | # Hash      | Group chat room                                         |
| **DM**      | Avatar      | Direct message between two users                        |

### 1.2 Hierarchy

```
Workspace (TeamSpace)
├── Projects
│   └── Project
│       ├── Lists
│       ├── Docs
│       └── Channels
├── Lists (standalone/ungrouped)
├── Docs (standalone/ungrouped)
├── Channels (standalone/ungrouped)
└── Direct Messages
```

### 1.3 Starring

- Any item (Project, List, Doc, Channel, DM) can be starred
- Starred items appear at the top of their respective category
- No global "Starred" section—stars are contextual within each category

---

## 2. Navigation & Layout

### 2.1 Two-Sidebar Layout

**Outer Sidebar (fixed, ~56px wide):**

- Home icon
- Projects icon
- Lists icon
- Docs icon
- Channels icon
- DMs icon
- Expand inner sidebar button (when collapsed)
- Current user avatar

**Inner Sidebar (collapsible, ~208px wide):**

- Header showing current category name
- List of items for selected category
- Starred items sorted to top (with ⭐ indicator)
- "New..." button at bottom
- Collapsible via clicking the right edge border

**Main Content Area:**

- Displays selected item (List, Doc, Channel, DM, or Home)
- Right panel for task details, threads, etc.

### 2.2 Icon Consistency

Icons are **fixed by type** and not customizable:

- Project: Folder icon
- List: Columns icon
- Doc: FileText icon
- Channel: Hash icon
- DM: User avatar

This enables muscle memory for quick visual scanning.

---

## 3. Core Features

### 3.1 Home

The Home view shows a personalized dashboard:

**Left Column (2/3):**

- **My Tasks** — Tasks assigned to current user, sorted by due date
  - "Today" badge for items due today
  - Click to navigate to task
- **Mentions** — Messages where user was @mentioned
  - Shows: who, which channel, message preview, time
- **Recently Edited** — Lists and Docs recently modified
  - Shows: item type icon, name, project (if any), who edited, time

**Right Column (1/3):**

- **Unreads** — Channels and DMs with unread messages
  - Shows: icon, name, unread count, preview, time
- **Quick Actions** — New canvas, New list, New project buttons
- **Tip Card** — Contextual tips (e.g., keyboard shortcuts)

### 3.2 Projects

A Project is a container that groups related items:

**Fields:**
| Field | Type | Required |
|-------|------|----------|
| id | UUID | Yes |
| name | String | Yes |
| starred | Boolean | No (default: false) |
| created_by | User | Yes |
| created_at | Timestamp | Yes |
| items | Relation | List of Lists, Docs, Channels |

**Behavior:**

- Projects appear in the Projects category of inner sidebar
- Expandable/collapsible to show contained items
- Items inside a project are displayed flat (no indentation)
- Can contain any combination of Lists, Docs, and Channels

### 3.3 Lists (Task Management)

Lists are 2-level task containers with fixed fields.

#### 3.3.1 List Object

| Field      | Type      | Required                |
| ---------- | --------- | ----------------------- |
| id         | UUID      | Yes                     |
| name       | String    | Yes                     |
| starred    | Boolean   | No                      |
| project_id | UUID      | No (standalone if null) |
| created_by | User      | Yes                     |
| created_at | Timestamp | Yes                     |

#### 3.3.2 Task Object (Parent)

| Field       | Type                    | Required            |
| ----------- | ----------------------- | ------------------- |
| id          | UUID                    | Yes                 |
| title       | String                  | Yes                 |
| status      | Enum: todo, doing, done | Yes (default: todo) |
| assigned_to | User                    | No                  |
| due_on      | Date                    | No                  |
| notes       | Text                    | No                  |
| created_by  | User                    | Yes                 |
| created_at  | Timestamp               | Yes                 |
| subtasks    | Relation                | Array of Subtasks   |
| comments    | Relation                | Array of Comments   |

#### 3.3.3 Subtask Object (Child)

| Field       | Type             | Required            |
| ----------- | ---------------- | ------------------- |
| id          | UUID             | Yes                 |
| title       | String           | Yes                 |
| status      | Enum: todo, done | Yes (default: todo) |
| assigned_to | User             | No                  |
| notes       | Text             | No                  |
| created_by  | User             | Yes                 |
| created_at  | Timestamp        | Yes                 |
| comments    | Relation         | Array of Comments   |

#### 3.3.4 List Views

**Board View:**

- 3 columns: To Do, In Progress, Done
- Cards show: title, due date, subtask progress, comment count, assignee avatar
- Click card → opens Task Detail Panel on right

**Table View:**

- Rows grouped by status sections
- Columns: Title, Due Date, Assignee, Subtask Progress
- Click row → opens Task Detail Panel on right

**Task Detail Panel (right sidebar, ~480px):**

- Title
- Status (badge)
- Assigned to (avatar + name)
- Due on (date)
- Created by (avatar + name + date)
- Notes (text)
- Subtasks (list with checkboxes, click to expand subtask detail)
- Comments (with thread + quote support)

**Subtask Detail Panel:**

- Back arrow to return to parent task
- Title with checkbox
- Assigned to
- Created by + date
- Notes
- Comments (with thread + quote support)

### 3.4 Docs

Docs are rich text posts by a single author, with comments below.

#### 3.4.1 Doc Object

| Field      | Type               | Required          |
| ---------- | ------------------ | ----------------- |
| id         | UUID               | Yes               |
| title      | String             | Yes               |
| content    | Rich Text (Tiptap) | Yes               |
| author     | User               | Yes               |
| starred    | Boolean            | No                |
| project_id | UUID               | No                |
| created_at | Timestamp          | Yes               |
| updated_at | Timestamp          | Yes               |
| comments   | Relation           | Array of Comments |

#### 3.4.2 Doc View

**Header:**

- Title
- Edit button (visible to author/admins only)

**Content Card:**

- Author avatar + name
- "Posted [date] · Updated [date]"
- Rich text content

**Comments Section:**

- Comment count
- List of comments (flat, not inline)
- Each comment supports threads + quote replies
- Add comment input at bottom

#### 3.4.3 Doc Editing

- Single author editing (no real-time collaboration)
- Rich text editor using Tiptap
- Supports: headings, bold, italic, lists, links, code blocks
- Autosave or explicit save

### 3.5 Channels

Group chat rooms for team communication.

#### 3.5.1 Channel Object

| Field      | Type      | Required |
| ---------- | --------- | -------- |
| id         | UUID      | Yes      |
| name       | String    | Yes      |
| starred    | Boolean   | No       |
| project_id | UUID      | No       |
| created_by | User      | Yes      |
| created_at | Timestamp | Yes      |

#### 3.5.2 Channel View

**Header:**

- Hash icon + channel name
- Search icon

**Message List:**

- Chronological messages
- Each message shows: avatar, name, time, content
- Hover actions: Quote, Reply in thread
- Thread indicator: avatar stack + "N replies" link

**Input:**

- Text input with placeholder "Message #channel-name"
- Send button

### 3.6 Direct Messages

Private 1:1 conversations.

#### 3.6.1 DM Object

| Field        | Type              | Required |
| ------------ | ----------------- | -------- |
| id           | UUID              | Yes      |
| participants | Array[2] of Users | Yes      |
| starred      | Boolean           | No       |
| created_at   | Timestamp         | Yes      |

#### 3.6.2 DM View

Same as Channel View, but:

- Header shows avatar + user name instead of hash + channel name
- Input placeholder: "Message [name]"

---

## 4. Universal Comment/Message System

**All comments and chat messages follow the same model:**

### 4.1 Message Object

| Field      | Type           | Required                         |
| ---------- | -------------- | -------------------------------- |
| id         | UUID           | Yes                              |
| content    | Text/Rich Text | Yes                              |
| author     | User           | Yes                              |
| created_at | Timestamp      | Yes                              |
| quote_id   | UUID           | No (reference to quoted message) |
| thread     | Relation       | Array of Messages (replies)      |

### 4.2 Threading Rules

1. Any message can start a thread
2. Replies live inside the thread (one level deep only—no nested threads)
3. Any message (top-level OR reply) can quote any other message
4. Quote reply ≠ thread reply—you can quote a message from anywhere

### 4.3 Thread Panel

- Opens on right side (~384px)
- Header: "Thread" + close button
- Parent message at top
- Replies below
- Reply input at bottom with quote indicator if quoting

### 4.4 Quote Display

- Appears above the message content
- Shows: connector line, quoted author avatar, name, truncated text
- Clicking quote jumps to original message

---

## 5. User System

### 5.1 User Object

| Field           | Type             | Required |
| --------------- | ---------------- | -------- |
| id              | UUID             | Yes      |
| name            | String           | Yes      |
| email           | String           | Yes      |
| avatar_initials | String (2 chars) | Yes      |
| avatar_color    | String (hex)     | Yes      |
| online_status   | Boolean          | Yes      |

### 5.2 Presence

- Online indicator (green dot) on avatars
- Shown in DM list and anywhere avatars appear

---

## 6. Technical Specifications

### 6.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Client                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              React PWA (Vite)                         │  │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐  │  │
│  │  │ Zustand │ │ React   │ │ Phoenix │ │ Service     │  │  │
│  │  │ Stores  │ │ Router  │ │ Socket  │ │ Worker      │  │  │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS + WebSocket
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Phoenix Server                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │ REST API    │ │ Channels    │ │ Presence            │   │
│  │ Controllers │ │ (WebSocket) │ │ (Online Status)     │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Business Logic (Contexts)              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      PostgreSQL                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Tech Stack

**Backend:**
| Technology | Purpose |
|------------|---------|
| Elixir | Language |
| Phoenix 1.7+ | Web framework |
| Phoenix Channels | Real-time WebSocket |
| Phoenix Presence | Online status tracking |
| Ecto | Database ORM |
| PostgreSQL | Database |

**Frontend:**
| Technology | Purpose |
|------------|---------|
| React 18 | UI library |
| Vite 5 | Build tool |
| TypeScript | Type safety |
| React Router 6 | Client-side routing |
| Zustand | State management |
| Phoenix JS | WebSocket client |
| Tiptap | Rich text editor (for Docs) |
| Tailwind CSS | Styling |
| Lucide React | Icons |
| Workbox | Service worker / PWA |

### 6.3 Repository Structure

```
missionspace/
├── server/                       # Phoenix backend
│   ├── lib/
│   │   ├── missionspace/              # Business logic
│   │   │   ├── accounts/        # Users, auth
│   │   │   ├── projects/        # Projects context
│   │   │   ├── lists/           # Lists, tasks, subtasks
│   │   │   ├── docs/            # Docs context
│   │   │   └── chat/            # Channels, DMs, messages
│   │   │
│   │   └── missionspace_web/          # Web layer
│   │       ├── controllers/     # REST API
│   │       ├── channels/        # WebSocket channels
│   │       │   ├── user_socket.ex
│   │       │   ├── project_channel.ex
│   │       │   ├── list_channel.ex
│   │       │   ├── doc_channel.ex
│   │       │   └── chat_channel.ex
│   │       └── router.ex
│   │
│   ├── priv/
│   │   └── repo/migrations/
│   ├── config/
│   ├── mix.exs
│   └── mix.lock
│
├── web/                          # React PWA frontend
│   ├── src/
│   │   ├── main.tsx             # Entry point
│   │   ├── App.tsx              # Root component + providers
│   │   ├── router.tsx           # React Router config
│   │   │
│   │   ├── components/          # Reusable components
│   │   │   ├── ui/              # Base UI (Button, Input, Avatar, etc.)
│   │   │   ├── layout/          # Sidebars, panels
│   │   │   │   ├── OuterSidebar.tsx
│   │   │   │   ├── InnerSidebar.tsx
│   │   │   │   ├── MainContent.tsx
│   │   │   │   └── DetailPanel.tsx
│   │   │   ├── list/            # List components
│   │   │   │   ├── BoardView.tsx
│   │   │   │   ├── TableView.tsx
│   │   │   │   ├── TaskCard.tsx
│   │   │   │   ├── TaskDetail.tsx
│   │   │   │   └── SubtaskDetail.tsx
│   │   │   ├── doc/             # Doc components
│   │   │   │   ├── DocView.tsx
│   │   │   │   ├── DocEditor.tsx
│   │   │   │   └── DocComments.tsx
│   │   │   ├── chat/            # Chat components
│   │   │   │   ├── MessageList.tsx
│   │   │   │   ├── Message.tsx
│   │   │   │   ├── MessageInput.tsx
│   │   │   │   ├── ThreadPanel.tsx
│   │   │   │   └── QuotedMessage.tsx
│   │   │   └── project/         # Project components
│   │   │       └── ProjectList.tsx
│   │   │
│   │   ├── pages/               # Route pages
│   │   │   ├── HomePage.tsx
│   │   │   ├── ProjectsPage.tsx
│   │   │   ├── ListsPage.tsx
│   │   │   ├── ListDetailPage.tsx
│   │   │   ├── DocsPage.tsx
│   │   │   ├── DocDetailPage.tsx
│   │   │   ├── ChannelsPage.tsx
│   │   │   ├── ChannelDetailPage.tsx
│   │   │   ├── DMsPage.tsx
│   │   │   └── DMDetailPage.tsx
│   │   │
│   │   ├── stores/              # Zustand stores
│   │   │   ├── authStore.ts     # Current user, auth state
│   │   │   ├── uiStore.ts       # Sidebar state, active category
│   │   │   ├── projectStore.ts  # Projects
│   │   │   ├── listStore.ts     # Lists, tasks, subtasks
│   │   │   ├── docStore.ts      # Docs
│   │   │   ├── chatStore.ts     # Channels, DMs, messages
│   │   │   └── presenceStore.ts # Online users
│   │   │
│   │   ├── hooks/               # Custom hooks
│   │   │   ├── useSocket.ts     # Phoenix socket connection
│   │   │   ├── useChannel.ts    # Phoenix channel subscription
│   │   │   ├── usePresence.ts   # Presence tracking
│   │   │   ├── useApi.ts        # REST API calls
│   │   │   └── useDebounce.ts
│   │   │
│   │   ├── lib/                 # Utilities
│   │   │   ├── api.ts           # Fetch wrapper
│   │   │   ├── socket.ts        # Phoenix socket singleton
│   │   │   ├── utils.ts         # Helpers
│   │   │   └── constants.ts
│   │   │
│   │   └── types/               # TypeScript types
│   │       ├── index.ts
│   │       ├── user.ts
│   │       ├── project.ts
│   │       ├── list.ts
│   │       ├── doc.ts
│   │       └── chat.ts
│   │
│   ├── public/
│   │   ├── manifest.json        # PWA manifest
│   │   ├── sw.js                # Service worker
│   │   └── icons/               # App icons
│   │       ├── icon-192.png
│   │       └── icon-512.png
│   │
│   ├── index.html
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   ├── postcss.config.js
│   ├── tsconfig.json
│   └── package.json
│
├── README.md
└── docker-compose.yml           # Local dev (PostgreSQL)
```

### 6.4 Frontend Dependencies

```json
{
  "name": "missionspace-web",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext ts,tsx"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "zustand": "^4.4.0",
    "phoenix": "^1.7.0",
    "lucide-react": "^0.300.0",
    "@tiptap/react": "^2.1.0",
    "@tiptap/starter-kit": "^2.1.0",
    "@tiptap/extension-placeholder": "^2.1.0",
    "date-fns": "^2.30.0",
    "clsx": "^2.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/phoenix": "^1.6.0",
    "@vitejs/plugin-react": "^4.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "vite-plugin-pwa": "^0.17.0",
    "workbox-precaching": "^7.0.0",
    "workbox-routing": "^7.0.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "eslint": "^8.55.0",
    "@typescript-eslint/eslint-plugin": "^6.13.0",
    "@typescript-eslint/parser": "^6.13.0"
  }
}
```

### 6.5 PWA Configuration

**vite.config.ts:**

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["icons/*.png"],
      manifest: {
        name: "Missionspace",
        short_name: "Missionspace",
        description: "Where teams steer their projects",
        theme_color: "#0f172a",
        background_color: "#0f172a",
        display: "standalone",
        icons: [
          {
            src: "/icons/icon-192.png",
            sizes: "192x192",
            type: "image/png",
          },
          {
            src: "/icons/icon-512.png",
            sizes: "512x512",
            type: "image/png",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,ico,png,svg}"],
      },
    }),
  ],
});
```

**PWA Capabilities:**
| Feature | Implementation |
|---------|----------------|
| Installable | manifest.json + service worker |
| Offline support | Workbox caching strategies |
| Push notifications | Phoenix + Web Push API |
| Background sync | Workbox background sync |
| App badging | Navigator.setAppBadge() |

### 6.6 Phoenix Channels Structure

**Channels:**
| Channel | Purpose | Events |
|---------|---------|--------|
| `user:*` | User-specific updates | notifications, unread counts |
| `project:*` | Project updates | item_added, item_removed |
| `list:*` | List/task updates | task_created, task_updated, task_moved |
| `doc:*` | Doc updates | doc_updated, comment_added |
| `chat:*` | Channel/DM messages | new_message, message_updated, typing |
| `presence` | Online status | presence_diff |

**Example channel (Elixir):**

```elixir
defmodule MissionspaceWeb.ChatChannel do
  use MissionspaceWeb, :channel

  def join("chat:" <> channel_id, _params, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :channel_id, channel_id)}
  end

  def handle_info(:after_join, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("new_message", %{"content" => content}, socket) do
    message = Chat.create_message!(socket.assigns.channel_id, content)
    broadcast!(socket, "new_message", message)
    {:noreply, socket}
  end
end
```

**Example hook (TypeScript):**

```typescript
// hooks/useChannel.ts
import { useEffect, useState } from "react";
import { socket } from "../lib/socket";
import type { Channel } from "phoenix";

export function useChannel<T>(
  topic: string,
  onMessage: (event: string, payload: T) => void,
) {
  const [channel, setChannel] = useState<Channel | null>(null);

  useEffect(() => {
    const ch = socket.channel(topic);

    ch.join()
      .receive("ok", () => console.log(`Joined ${topic}`))
      .receive("error", (err) => console.error(`Failed to join ${topic}`, err));

    ch.onMessage = (event, payload) => {
      onMessage(event, payload as T);
      return payload;
    };

    setChannel(ch);
    return () => {
      ch.leave();
    };
  }, [topic]);

  return channel;
}
```

### 6.7 Responsive Breakpoints

| Breakpoint | Width          | Layout                                      |
| ---------- | -------------- | ------------------------------------------- |
| Mobile     | < 640px        | Bottom tabs, no sidebars, full-screen pages |
| Tablet     | 640px - 1024px | Outer sidebar + collapsible inner sidebar   |
| Desktop    | > 1024px       | Full two-sidebar layout                     |

**Mobile layout:**

- Outer sidebar → Bottom tab bar
- Inner sidebar → Full-screen page with back navigation
- Detail panels → Full-screen with back navigation
- Thread panel → Full-screen overlay

```sql
-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  avatar_initials VARCHAR(2) NOT NULL,
  avatar_color VARCHAR(7) NOT NULL,
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Projects
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  starred BOOLEAN DEFAULT FALSE,
  created_by_id UUID REFERENCES users(id),
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Lists
CREATE TABLE lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  starred BOOLEAN DEFAULT FALSE,
  project_id UUID REFERENCES projects(id),
  created_by_id UUID REFERENCES users(id),
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Tasks
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id UUID REFERENCES lists(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  status VARCHAR(20) DEFAULT 'todo',
  assigned_to_id UUID REFERENCES users(id),
  due_on DATE,
  notes TEXT,
  created_by_id UUID REFERENCES users(id),
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Subtasks
CREATE TABLE subtasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  status VARCHAR(20) DEFAULT 'todo',
  assigned_to_id UUID REFERENCES users(id),
  notes TEXT,
  created_by_id UUID REFERENCES users(id),
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Docs
CREATE TABLE docs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  content TEXT,
  starred BOOLEAN DEFAULT FALSE,
  project_id UUID REFERENCES projects(id),
  author_id UUID REFERENCES users(id),
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Channels
CREATE TABLE channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  starred BOOLEAN DEFAULT FALSE,
  project_id UUID REFERENCES projects(id),
  created_by_id UUID REFERENCES users(id),
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Direct Message Threads
CREATE TABLE dm_threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  starred BOOLEAN DEFAULT FALSE,
  inserted_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE dm_participants (
  dm_thread_id UUID REFERENCES dm_threads(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  PRIMARY KEY (dm_thread_id, user_id)
);

-- Messages (for channels and DMs)
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  author_id UUID REFERENCES users(id),
  channel_id UUID REFERENCES channels(id),
  dm_thread_id UUID REFERENCES dm_threads(id),
  parent_message_id UUID REFERENCES messages(id), -- for threads
  quote_message_id UUID REFERENCES messages(id), -- for quotes
  inserted_at TIMESTAMP DEFAULT NOW(),
  CHECK (
    (channel_id IS NOT NULL AND dm_thread_id IS NULL) OR
    (channel_id IS NULL AND dm_thread_id IS NOT NULL)
  )
);

-- Comments (for tasks, subtasks, docs)
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  author_id UUID REFERENCES users(id),
  task_id UUID REFERENCES tasks(id),
  subtask_id UUID REFERENCES subtasks(id),
  doc_id UUID REFERENCES docs(id),
  parent_comment_id UUID REFERENCES comments(id), -- for threads
  quote_comment_id UUID REFERENCES comments(id), -- for quotes
  inserted_at TIMESTAMP DEFAULT NOW(),
  CHECK (
    (task_id IS NOT NULL AND subtask_id IS NULL AND doc_id IS NULL) OR
    (task_id IS NULL AND subtask_id IS NOT NULL AND doc_id IS NULL) OR
    (task_id IS NULL AND subtask_id IS NULL AND doc_id IS NOT NULL)
  )
);

-- Indexes
CREATE INDEX idx_tasks_list_id ON tasks(list_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_subtasks_task_id ON subtasks(task_id);
CREATE INDEX idx_messages_channel_id ON messages(channel_id);
CREATE INDEX idx_messages_dm_thread_id ON messages(dm_thread_id);
CREATE INDEX idx_comments_task_id ON comments(task_id);
CREATE INDEX idx_comments_doc_id ON comments(doc_id);
```

## 7. API Design

### 7.1 REST Endpoints

**Authentication:**

```
POST   /api/auth/register
POST   /api/auth/login
DELETE /api/auth/logout
GET    /api/auth/me
```

**Projects:**

```
GET    /api/projects
POST   /api/projects
GET    /api/projects/:id
PATCH  /api/projects/:id
DELETE /api/projects/:id
POST   /api/projects/:id/star
DELETE /api/projects/:id/star
```

**Lists:**

```
GET    /api/lists
POST   /api/lists
GET    /api/lists/:id
PATCH  /api/lists/:id
DELETE /api/lists/:id
POST   /api/lists/:id/star
```

**Tasks:**

```
GET    /api/lists/:list_id/tasks
POST   /api/lists/:list_id/tasks
GET    /api/tasks/:id
PATCH  /api/tasks/:id
DELETE /api/tasks/:id
PATCH  /api/tasks/:id/move          # Change status/order
```

**Subtasks:**

```
GET    /api/tasks/:task_id/subtasks
POST   /api/tasks/:task_id/subtasks
GET    /api/subtasks/:id
PATCH  /api/subtasks/:id
DELETE /api/subtasks/:id
```

**Docs:**

```
GET    /api/docs
POST   /api/docs
GET    /api/docs/:id
PATCH  /api/docs/:id
DELETE /api/docs/:id
POST   /api/docs/:id/star
```

**Channels:**

```
GET    /api/channels
POST   /api/channels
GET    /api/channels/:id
PATCH  /api/channels/:id
DELETE /api/channels/:id
POST   /api/channels/:id/star
GET    /api/channels/:id/messages
```

**DMs:**

```
GET    /api/dms
POST   /api/dms                      # Start new DM thread
GET    /api/dms/:id/messages
POST   /api/dms/:id/star
```

**Comments:**

```
GET    /api/tasks/:task_id/comments
POST   /api/tasks/:task_id/comments
GET    /api/subtasks/:subtask_id/comments
POST   /api/subtasks/:subtask_id/comments
GET    /api/docs/:doc_id/comments
POST   /api/docs/:doc_id/comments
DELETE /api/comments/:id
```

### 7.2 WebSocket Events

**Client → Server:**
| Channel | Event | Payload |
|---------|-------|---------|
| chat:_ | new_message | { content, quote_id? } |
| chat:_ | typing | {} |
| chat:_ | stop_typing | {} |
| list:_ | task_moved | { task_id, status, position } |
| doc:\* | comment_added | { content, quote_id?, parent_id? } |

**Server → Client:**
| Channel | Event | Payload |
|---------|-------|---------|
| chat:_ | new_message | Message object |
| chat:_ | user_typing | { user_id } |
| list:_ | task_created | Task object |
| list:_ | task_updated | Task object |
| list:_ | task_deleted | { task_id } |
| doc:_ | doc_updated | Doc object |
| doc:_ | comment_added | Comment object |
| user:_ | notification | Notification object |
| presence | presence_state | { user_id: { online_at } } |
| presence | presence_diff | { joins, leaves } |

---

## 8. Implementation Phases

### Phase 1: Foundation (Week 1-2)

- [ ] Initialize Phoenix project with PostgreSQL
- [ ] Initialize React + Vite project with TypeScript
- [ ] Set up Tailwind CSS
- [ ] User authentication (register, login, logout)
- [ ] Database schema and migrations
- [ ] Basic two-sidebar layout (outer + inner)
- [ ] Navigation between categories
- [ ] PWA manifest and service worker setup

### Phase 2: Lists & Tasks (Week 3-4)

- [ ] Lists CRUD API
- [ ] Tasks CRUD API with all fields
- [ ] Subtasks CRUD API
- [ ] Board view component
- [ ] Table view component
- [ ] Task detail panel
- [ ] Subtask detail panel
- [ ] Phoenix Channel for real-time task updates
- [ ] Drag-and-drop task status changes

### Phase 3: Docs (Week 5)

- [ ] Docs CRUD API
- [ ] Tiptap editor integration
- [ ] Doc view with author info
- [ ] Edit mode with autosave
- [ ] Doc comments API
- [ ] Comments section with threading

### Phase 4: Chat (Week 6-7)

- [ ] Channels CRUD API
- [ ] Messages API
- [ ] Phoenix Channel for real-time messaging
- [ ] Message list with infinite scroll
- [ ] Message input with send
- [ ] DM threads API
- [ ] Phoenix Presence for online status
- [ ] Typing indicators

### Phase 5: Threading & Quotes (Week 8)

- [ ] Thread replies (one level)
- [ ] Quote reply functionality
- [ ] Thread panel component
- [ ] Quote display component
- [ ] Unified comment system for tasks/subtasks/docs

### Phase 6: Projects & Organization (Week 9)

- [ ] Projects CRUD API
- [ ] Assign items to projects
- [ ] Project view in inner sidebar
- [ ] Starring system (projects, lists, docs, channels, DMs)
- [ ] Starred items sorting
- [ ] Home dashboard with recent items

### Phase 7: Polish & PWA (Week 10)

- [ ] Search functionality
- [ ] Keyboard shortcuts
- [ ] Push notifications
- [ ] Offline support (Workbox)
- [ ] App badging for unread counts
- [ ] Responsive mobile layout
- [ ] Empty states
- [ ] Error handling and toasts
- [ ] Loading skeletons

---

## 9. Design Tokens

### Colors (Dark Theme)

```css
--bg-outer-sidebar: #0a0a0f (slate-950) --bg-inner-sidebar: #0f172a (slate-900)
  --bg-main: #f8fafc (slate-50) --bg-card: #ffffff --bg-hover: #1e293b
  (slate-800) --bg-active: #334155 (slate-700) --text-primary: #1e293b
  (slate-800) --text-secondary: #64748b (slate-500) --text-muted: #94a3b8
  (slate-400) --text-sidebar: #cbd5e1 (slate-300) --accent-blue: #3b82f6
  (blue-500) --accent-green: #22c55e (green-500) --accent-yellow: #eab308
  (yellow-500) --accent-red: #ef4444 (red-500) --status-todo: #f1f5f9
  (slate-100) --status-doing: #dbeafe (blue-100) --status-done: #dcfce7
  (green-100);
```

### Typography

```css
--font-family:
  system-ui, -apple-system,
  sans-serif --font-size-xs: 12px --font-size-sm: 14px --font-size-base: 14px
    --font-size-lg: 18px --font-size-xl: 20px --font-size-2xl: 24px;
```

### Spacing

```css
--spacing-1: 4px --spacing-2: 8px --spacing-3: 12px --spacing-4: 16px
  --spacing-6: 24px --spacing-8: 32px;
```

### Sizing

```css
--outer-sidebar-width: 56px --inner-sidebar-width: 208px
  --detail-panel-width: 480px --thread-panel-width: 384px --avatar-xs: 16px
  --avatar-sm: 24px --avatar-md: 32px;
```

---

## 10. Keyboard Shortcuts

| Shortcut | Action                                                       |
| -------- | ------------------------------------------------------------ |
| ⌘ K      | Command palette / Quick search                               |
| ⌘ N      | New item (context-aware)                                     |
| ⌘ /      | Toggle sidebar                                               |
| ⌘ 1-6    | Switch category (Home, Projects, Lists, Docs, Channels, DMs) |
| Esc      | Close panel / Cancel                                         |
| ⌘ Enter  | Send message / Save                                          |

---

## 11. Success Metrics

1. **Performance**: < 100ms for all UI interactions
2. **Adoption**: Users create at least 1 project, 1 list, 1 doc in first week
3. **Engagement**: Daily active usage of chat features
4. **Retention**: 80% weekly retention after onboarding

## 12. Deployment

### 12.1 Development Setup

```bash
# Prerequisites
# - Elixir 1.15+
# - Node.js 20+
# - PostgreSQL 15+

# Clone and setup
git clone https://github.com/yourusername/missionspace.git
cd missionspace

# Start PostgreSQL (via Docker)
docker-compose up -d

# Backend setup
cd server
mix deps.get
mix ecto.setup
mix phx.server

# Frontend setup (new terminal)
cd web
npm install
npm run dev
```

### 12.2 Production Deployment

**Recommended: Fly.io**

```bash
# Backend
cd server
fly launch
fly deploy

# Frontend (static hosting)
cd web
npm run build
# Deploy dist/ to Vercel, Cloudflare Pages, or Fly.io
```

**Environment Variables:**

```bash
# Server
DATABASE_URL=postgres://...
SECRET_KEY_BASE=...
PHX_HOST=missionspace.example.com

# Client
VITE_API_URL=https://api.missionspace.example.com
VITE_WS_URL=wss://api.missionspace.example.com
```

---

## Appendix A: UI Prototype

The interactive prototype is available in `docs/prototype.html`. It demonstrates:

- Two-sidebar navigation
- List board/table views with task details
- Doc view with comments
- Channel chat with threads and quote replies
- Collapsible inner sidebar
