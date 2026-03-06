---
name: architecture
description: Missionspace project architecture patterns, error handling, multi-tenancy, and UUIDs. Use when implementing new features, refactoring code, or explaining architectural decisions.
---

# Missionspace Architecture Patterns

## Error Handling Pattern

**ALWAYS use tuple returns, NEVER use bang functions:**

```elixir
# ✅ GOOD - Tuple returns
def get_doc(id, workspace_id) do
  case Doc
       |> where([d], d.workspace_id == ^workspace_id)
       |> Repo.get(id) do
    nil -> {:error, :not_found}
    doc -> {:ok, doc}
  end
end

# ❌ BAD - Bang function that raises exceptions
def get_doc!(id, workspace_id) do
  Doc
  |> where([d], d.workspace_id == ^workspace_id)
  |> Repo.get!(id)
end
```

## Controller Pattern

Controllers use `with` statements and rely on `FallbackController` for error handling:

```elixir
defmodule MissionspaceWeb.DocController do
  use MissionspaceWeb, :controller

  action_fallback(MissionspaceWeb.FallbackController)

  # ✅ GOOD - Clean with statement
  def show(conn, %{"id" => id}) do
    workspace_id = conn.assigns.workspace_id

    with {:ok, doc} <- Docs.get_doc(id, workspace_id) do
      render(conn, :show, doc: doc)
    end
  end
end
```

The `FallbackController` automatically handles:

- `{:error, :not_found}` → 404 response
- `{:error, %Ecto.Changeset{}}` → 422 response with validation errors

## Multi-tenancy with Workspace Isolation

All resources are scoped to workspaces:

```elixir
# Always include workspace_id in queries
def list_docs(workspace_id, opts) do
  Doc
  |> where([d], d.workspace_id == ^workspace_id)
  |> # ... pagination, ordering, etc
end
```

## UUIDs and Primary Keys

Package: `{:uuidv7, "~> 1.0"}`

Use UUIDv7 (time-sortable) for all primary keys:

```elixir
schema "docs" do
  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID

  field(:title, :string)
  field(:content, :string, default: "")

  belongs_to(:workspace, Missionspace.Accounts.Workspace)
  belongs_to(:author, Missionspace.Accounts.User)

  timestamps()
end

# In the migration
create table(:docs, primary_key: false) do
  add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
  # ...
end
```

**Benefits**: Time-ordered IDs, better database index performance, distributed-safe.

## Pagination

Package: `{:paginator, "~> 1.2"}`

All list endpoints use cursor-based pagination for better performance and consistency.

**Configuration**:

- Default limit: 50 items per page
- Always use `desc: id` for default sorting
- Maintain composite indices on `(workspace_id, id)` for optimal performance

**Query parameters**:

- `after`: Cursor for next page
- `before`: Cursor for previous page
- `limit`: Items per page

**Example**:

```elixir
def list_docs(workspace_id, opts) do
  Doc
  |> where([d], d.workspace_id == ^workspace_id)
  |> order_by([d], desc: d.id)
  |> Paginator.paginate(opts)
end
```

## Database Indices

For paginated resources, create composite indices for optimal performance:

```elixir
# Migration
create index(:docs, [:workspace_id])
create index(:docs, [:workspace_id, :id])
```

Both single-column and composite indices are maintained for different query patterns.

## Authentication & Authorization

All API endpoints require authentication via session cookies and workspace context.

**Critical**: All queries MUST filter by `workspace_id` to prevent cross-workspace data leakage.

## Role-Based Access Control (RBAC)

Missionspace implements a role-based permission system with three roles:

### Roles

| Role       | Description                                                        |
| ---------- | ------------------------------------------------------------------ |
| **owner**  | Full access to everything in workspace, can manage members         |
| **member** | Access only to assigned projects, can only update/delete own items |
| **guest**  | Same as member but limited to ONE project                          |

### Permission Rules

| Action                            | Owner | Member | Guest      |
| --------------------------------- | ----- | ------ | ---------- |
| See workspace-level items         | Yes   | No     | No         |
| See items in assigned projects    | Yes   | Yes    | Yes        |
| Create items in assigned projects | Yes   | Yes    | Yes        |
| Update ANY item                   | Yes   | No     | No         |
| Update OWN items                  | Yes   | Yes    | Yes        |
| Delete ANY item                   | Yes   | No     | No         |
| Delete OWN items                  | Yes   | Yes    | Yes        |
| Comment on viewable items         | Yes   | Yes    | Yes        |
| Manage workspace members          | Yes   | No     | No         |
| Manage project members            | Yes   | No     | No         |
| Multiple project assignments      | Yes   | Yes    | No (max 1) |

### Authorization Implementation

Authorization is implemented via plugs in controllers:

```elixir
defmodule MissionspaceWeb.DocController do
  plug :load_resource when action in [:show, :update, :delete]
  plug :authorize, :view_item when action in [:show]
  plug :authorize, :create_item when action in [:create]
  plug :authorize, :update_item when action in [:update]
  plug :authorize, :delete_item when action in [:delete]

  defp load_resource(conn, _opts) do
    case Docs.get_doc(conn.params["id"], conn.assigns.workspace_id) do
      {:ok, doc} -> assign(conn, :doc, doc)
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  defp authorize(conn, permission) do
    user = conn.assigns.current_user
    resource = conn.assigns[:doc]

    if Policy.can?(user, permission, resource) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Forbidden"})
      |> halt()
    end
  end
end
```

### Policy Module

The `Missionspace.Authorization.Policy` module defines all permission rules:

```elixir
# Owner can do anything
def can?(%User{role: "owner"}, _action, _resource), do: true

# Members/guests check project membership and ownership
# Project ID is looked up via project_items table
def can?(user, :view_item, item) do
  project_id = Projects.get_item_project_id(item_type(item), item.id)
  is_project_member?(user, project_id)
end

def can?(user, :update_item, item) do
  project_id = Projects.get_item_project_id(item_type(item), item.id)
  is_creator?(user, item) and is_project_member?(user, project_id)
end
```

### Key Tables

- `users.role` - Role field ("owner", "member", "guest")
- `project_members` - Join table linking users to projects
- `project_items` - Polymorphic join table linking projects to docs/lists/channels
- Items have `created_by_id` or `author_id` for ownership tracking

## Project Items (Polymorphic Association)

Items (docs, lists, channels) are linked to projects via the `project_items` join table:

```elixir
# project_items schema
schema "project_items" do
  field :item_type, :string  # "doc", "list", "channel"
  field :item_id, :binary_id
  belongs_to :project, Project
  timestamps()
end
```

### Adding Items to Projects

```elixir
# Add a doc to a project
Projects.add_item(project_id, "doc", doc.id)

# Remove an item from its project
Projects.remove_item("doc", doc.id)

# Get the project ID for an item
Projects.get_item_project_id("doc", doc.id)  # Returns project_id or nil
```

### Project with Items

Projects can be loaded with their items:

```elixir
# List projects with items preloaded
Projects.list_projects_with_items(workspace_id, user)

# Get a single project with items
Projects.get_project_with_items(id, workspace_id)
```

The `project_items` are returned in the API response and frontend uses them to filter which items belong to which project.

## Common Controller Patterns

### Creating Resources

```elixir
def create(conn, %{"resource" => resource_params}) do
  workspace_id = conn.assigns.workspace_id
  user = conn.assigns.current_user

  resource_params =
    resource_params
    |> Map.put("workspace_id", workspace_id)
    |> Map.put("author_id", user.id)

  with {:ok, resource} <- Context.create_resource(resource_params) do
    conn
    |> put_status(:created)
    |> render(:show, resource: resource)
  end
end
```

### Updating Resources

```elixir
def update(conn, %{"id" => id, "resource" => resource_params}) do
  workspace_id = conn.assigns.workspace_id

  with {:ok, resource} <- Context.get_resource(id, workspace_id),
       {:ok, resource} <- Context.update_resource(resource, resource_params) do
    render(conn, :show, resource: resource)
  end
end
```

### Deleting Resources

```elixir
def delete(conn, %{"id" => id}) do
  workspace_id = conn.assigns.workspace_id

  with {:ok, resource} <- Context.get_resource(id, workspace_id),
       {:ok, _resource} <- Context.delete_resource(resource) do
    send_resp(conn, :no_content, "")
  end
end
```
