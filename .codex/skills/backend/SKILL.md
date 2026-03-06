---
name: backend
description: Elixir/Phoenix backend development patterns for Missionspace. Use when working on controllers, contexts, schemas, or API endpoints.
user-invocable: false
---

# Missionspace Backend Development

## Context

When working on backend code, you're in the `server/` directory working with:

- **Controllers** (`lib/missionspace_web/controllers/`) - Handle HTTP requests
- **Contexts** (`lib/missionspace/`) - Business logic modules
- **Schemas** (`lib/missionspace/*/schema.ex`) - Database models
- **Tests** (`test/`) - Controller and context tests

## Development Principle: Test-Driven Development (TDD)

ALWAYS start with writing tests before implementing features:

1. Write controller/context tests that verify the behavior you're implementing
2. Run tests and see them fail
3. Implement the feature to make tests pass
4. Refactor if needed while keeping tests green

## Key Patterns

### Always use tuple returns in contexts

```elixir
# ✅ Correct pattern
def get_doc(id, workspace_id) do
  case Doc
       |> where([d], d.workspace_id == ^workspace_id)
       |> Repo.get(id) do
    nil -> {:error, :not_found}
    doc -> {:ok, doc}
  end
end
```

### Controllers use `with` and fallback

```elixir
def show(conn, %{"id" => id}) do
  workspace_id = conn.assigns.workspace_id

  with {:ok, doc} <- Docs.get_doc(id, workspace_id) do
    render(conn, :show, doc: doc)
  end
end
```

### Controllers accept FLAT params (no nested keys)

**IMPORTANT**: Controller actions should accept flat params directly, NOT nested under a key like `%{"doc" => params}`.

```elixir
# ❌ WRONG - Don't use nested params
def create(conn, %{"doc" => doc_params}) do
  # This requires frontend to send { doc: { title: "...", content: "..." } }
end

def update(conn, %{"doc" => doc_params}) do
  # Same issue
end

# ✅ CORRECT - Accept flat params
def create(conn, params) do
  # Frontend sends { title: "...", content: "..." } directly
  workspace_id = conn.assigns.workspace_id

  doc_params =
    params
    |> Map.put("workspace_id", workspace_id)
    |> Map.put("author_id", conn.assigns.current_user.id)

  with {:ok, doc} <- Docs.create_doc(doc_params) do
    conn
    |> put_status(:created)
    |> render(:show, doc: doc)
  end
end

def update(conn, params) do
  # Remove id since it's already loaded via plug
  doc_params = Map.drop(params, ["id"])

  with {:ok, doc} <- Docs.update_doc(conn.assigns.doc, doc_params) do
    render(conn, :show, doc: doc)
  end
end
```

**Why flat params?**

- Simpler frontend code - no need to wrap data in a key
- Consistent API contract across all endpoints
- Less boilerplate in both frontend and backend

### Always scope to workspace

```elixir
def list_docs(workspace_id, opts) do
  Doc
  |> where([d], d.workspace_id == ^workspace_id)
  |> order_by([d], desc: d.inserted_at)
  |> Repo.all()
end
```

## File Locations

- **Controllers**: `lib/missionspace_web/controllers/`
- **Context modules**: `lib/missionspace/`
- **Schemas**: Inside context directories
- **Tests**: `test/missionspace_web/controllers/` and `test/missionspace/`
- **Migrations**: `priv/repo/migrations/`

## Running Backend

```bash
cd server
mix phx.server      # Start server
mix test            # Run tests
mix format          # Format code
```
