---
name: testing
description: Test-Driven Development practices for Missionspace. Use when writing tests, implementing features, or ensuring test coverage. Includes factories, test structure, and meaningful test examples.
---

# Missionspace Testing Guide

## Development Principle: Test-Driven Development (TDD)

ALWAYS start with writing tests before implementing features:

1. Write meaningful integration tests that call actual API endpoints
2. Run tests and see them fail
3. Implement the feature to make tests pass
4. Refactor if needed while keeping tests green

## Test Setup

Tests use `MissionspaceWeb.ConnCase` for controller tests:

```elixir
defmodule MissionspaceWeb.DocControllerTest do
  use MissionspaceWeb.ConnCase

  setup do
    # Create test data using factories
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)

    # Authenticate conn (if your app has auth)
    conn = conn
           |> put_session(:user_id, user.id)
           |> put_req_header("accept", "application/json")

    {:ok, conn: conn, workspace: workspace, user: user}
  end
end
```

## Factory Pattern

Use ExMachina factories (in `test/support/factory.ex`):

```elixir
# Define factories
def workspace_factory do
  %Missionspace.Accounts.Workspace{
    name: "Test Workspace",
    slug: sequence(:slug, &"workspace-#{&1}")
  }
end

def user_factory do
  %Missionspace.Accounts.User{
    name: "Test User",
    email: sequence(:email, &"user-#{&1}@example.com"),
    password_hash: Bcrypt.hash_pwd_salt("password123"),
    workspace: build(:workspace)
  }
end

def doc_factory do
  %Missionspace.Docs.Doc{
    title: "Test Doc",
    content: "Test content",
    workspace: build(:workspace),
    author: build(:user)
  }
end

# Use in tests
workspace = insert(:workspace)
user = insert(:user, workspace_id: workspace.id)
doc = insert(:doc, workspace_id: workspace.id, author_id: user.id)
```

## Writing Meaningful Tests

**DO NOT** just insert data manually and read it back - that tests nothing!

**DO** create data through actual API endpoints and verify business logic:

```elixir
# ❌ BAD - meaningless test
test "lists docs", %{conn: conn, workspace: workspace} do
  doc = insert(:doc, workspace_id: workspace.id, title: "Test")

  response = conn
             |> get(~p"/api/docs")
             |> json_response(200)

  assert hd(response["data"])["title"] == "Test"
end

# ✅ GOOD - tests actual business logic
test "creates doc and includes it in list", %{conn: conn} do
  # Create through API
  create_response = conn
                    |> post(~p"/api/docs", %{doc: %{title: "Test Doc"}})
                    |> json_response(201)

  doc_id = create_response["data"]["id"]

  # Verify it appears in list
  list_response = conn
                  |> get(~p"/api/docs")
                  |> json_response(200)

  assert Enum.any?(list_response["data"], fn doc ->
    doc["id"] == doc_id && doc["title"] == "Test Doc"
  end)
end

# ✅ GOOD - tests workspace isolation
test "cannot access docs from other workspaces", %{conn: conn} do
  other_workspace = insert(:workspace)
  other_doc = insert(:doc, workspace_id: other_workspace.id)

  response = conn
             |> get(~p"/api/docs/#{other_doc.id}")
             |> json_response(404)

  assert response["errors"]["detail"] == "Doc not found"
end

# ✅ GOOD - tests validation
test "cannot create doc without title", %{conn: conn} do
  response = conn
             |> post(~p"/api/docs", %{doc: %{content: "Content only"}})
             |> json_response(422)

  assert response["errors"]["title"] == ["can't be blank"]
end
```

## Test Structure

Organize tests by controller action:

```elixir
defmodule MissionspaceWeb.DocControllerTest do
  use MissionspaceWeb.ConnCase

  describe "index" do
    test "returns all docs in workspace", %{conn: conn} do
      # Test implementation
    end

    test "does not return docs from other workspaces", %{conn: conn} do
      # Test implementation
    end

    test "supports pagination", %{conn: conn} do
      # Test implementation
    end
  end

  describe "create" do
    test "creates doc with valid attributes", %{conn: conn} do
      # Test implementation
    end

    test "returns error with invalid attributes", %{conn: conn} do
      # Test implementation
    end
  end

  describe "show" do
    test "returns doc when found", %{conn: conn} do
      # Test implementation
    end

    test "returns 404 when doc not found", %{conn: conn} do
      # Test implementation
    end
  end

  describe "update" do
    test "updates doc with valid attributes", %{conn: conn} do
      # Test implementation
    end

    test "returns 404 when doc not found", %{conn: conn} do
      # Test implementation
    end
  end

  describe "delete" do
    test "deletes doc when found", %{conn: conn} do
      # Test implementation
    end

    test "returns 404 when doc not found", %{conn: conn} do
      # Test implementation
    end
  end
end
```

## Running Tests

```bash
# Run all tests
cd server && mix test

# Run specific test file
mix test test/missionspace_web/controllers/doc_controller_test.exs

# Run specific test
mix test test/missionspace_web/controllers/doc_controller_test.exs:45

# Run tests with coverage
mix coveralls
```

## Test Coverage Goals

- **Controllers**: 100% coverage for all actions
- **Context modules**: 100% coverage for public functions
- **Channels**: Test join, handle_in callbacks, and broadcasts
