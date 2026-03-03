# Global Workspace Search (Spotlight / Cmd+K)

## Overview

A workspace-wide search that lets users quickly find any item using a single search bar, similar to Mac Spotlight or VS Code's Cmd+K.

## How It Works

- Search icon in the outer sidebar (above notification bell)
- Opens with `Cmd+K` / `Ctrl+K` keyboard shortcut
- Modal overlay with a search input + categorized results below
- 300ms debounced API calls as the user types
- Results grouped by category with headers: Projects, Boards, Tasks, Folders, Docs, Channels, Members
- Keyboard navigation: arrow keys to move, Enter to open, Escape to close
- Max 5 results per category

## Searchable Entities

| Entity | Searched Fields | Display |
|--------|----------------|---------|
| Projects | name | Briefcase icon + name |
| Boards | name, prefix | Kanban icon + prefix + name |
| Tasks | title, key (PREFIX-123) | CheckSquare icon + key + title + status badge |
| Doc Folders | name, prefix | Folder icon + name |
| Docs | title | FileText icon + key + title |
| Channels | name | Hash icon + name |
| Members | name, email | Avatar + name + email |

Messages are excluded (high volume, noisy).

## Navigation

Clicking a result navigates to:
- Project → `/projects/:id`
- Board → `/boards/:id`
- Task → `/boards/:boardId?task=:id`
- Doc Folder → `/doc-folders/:id`
- Doc → `/doc-folders/:folderId/docs/:id`
- Channel → `/channels/:id`
- Member → no navigation (informational only)

## Access Control

- All queries filtered by `workspace_id` (no cross-workspace leakage)
- Owner sees all shared items + own private items
- Member/Guest sees: project items + own items + explicitly invited shared items
- Uses existing `filter_accessible` helpers from `Bridge.Projects`

## Backend

- **API:** `GET /api/search?q=query`
- **Context:** `Bridge.Search.search/3` runs 7 concurrent ILIKE queries using `Task.async`
- **Performance:** GIN trigram indexes (`pg_trgm`) on all searchable text columns for fast ILIKE matching
- Task key search uses SQL fragment: `prefix || '-' || sequence_number::text`

## Key Files

- `server/lib/bridge/search.ex` — search context
- `server/lib/bridge_web/controllers/search_controller.ex` — controller
- `server/lib/bridge_web/controllers/search_json.ex` — JSON view
- `server/priv/repo/migrations/*_add_search_trigram_indexes.exs` — pg_trgm indexes
- `web/src/stores/searchStore.ts` — Zustand store
- `web/src/components/features/SearchModal.tsx` — spotlight modal
