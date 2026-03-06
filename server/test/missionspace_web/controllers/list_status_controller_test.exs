defmodule MissionspaceWeb.ListStatusControllerTest do
  use MissionspaceWeb.ConnCase

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)
    list = insert(:list, workspace_id: workspace.id)

    # Create default statuses for the list
    todo_status =
      insert(:list_status,
        list_id: list.id,
        name: "todo",
        color: "#6b7280",
        position: 0,
        is_done: false
      )

    doing_status =
      insert(:list_status,
        list_id: list.id,
        name: "doing",
        color: "#3b82f6",
        position: 1,
        is_done: false
      )

    done_status =
      insert(:list_status,
        list_id: list.id,
        name: "done",
        color: "#22c55e",
        position: 2,
        is_done: true
      )

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok,
     conn: conn,
     workspace: workspace,
     user: user,
     list: list,
     todo_status: todo_status,
     doing_status: doing_status,
     done_status: done_status}
  end

  describe "index" do
    test "returns all statuses for a list", %{
      conn: conn,
      list: list,
      todo_status: todo_status,
      doing_status: doing_status,
      done_status: done_status
    } do
      response =
        conn
        |> get(~p"/api/boards/#{list.id}/statuses")
        |> json_response(200)

      status_ids = Enum.map(response["data"], & &1["id"])
      assert todo_status.id in status_ids
      assert doing_status.id in status_ids
      assert done_status.id in status_ids
    end

    test "returns statuses ordered by position", %{conn: conn, list: list} do
      response =
        conn
        |> get(~p"/api/boards/#{list.id}/statuses")
        |> json_response(200)

      positions = Enum.map(response["data"], & &1["position"])
      assert positions == Enum.sort(positions)
    end

    test "does not return statuses from other lists", %{conn: conn, workspace: workspace} do
      other_list = insert(:list, workspace_id: workspace.id)
      other_status = insert(:list_status, list_id: other_list.id, name: "other", position: 0)

      response =
        conn
        |> get(~p"/api/boards/#{other_list.id}/statuses")
        |> json_response(200)

      status_ids = Enum.map(response["data"], & &1["id"])
      assert other_status.id in status_ids
      assert length(status_ids) == 1
    end

    test "returns 404 for list from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)

      conn
      |> get(~p"/api/boards/#{other_list.id}/statuses")
      |> json_response(404)
    end
  end

  describe "create" do
    test "creates status with valid attributes", %{conn: conn, list: list} do
      response =
        conn
        |> post(~p"/api/boards/#{list.id}/statuses", %{name: "Review", color: "#8b5cf6"})
        |> json_response(201)

      # Name is uppercased on create
      assert response["data"]["name"] == "REVIEW"
      assert response["data"]["color"] == "#8b5cf6"
      assert response["data"]["list_id"] == list.id
    end

    test "created status appears in index", %{conn: conn, list: list} do
      create_response =
        conn
        |> post(~p"/api/boards/#{list.id}/statuses", %{name: "Review", color: "#8b5cf6"})
        |> json_response(201)

      status_id = create_response["data"]["id"]

      index_response =
        conn
        |> get(~p"/api/boards/#{list.id}/statuses")
        |> json_response(200)

      status_ids = Enum.map(index_response["data"], & &1["id"])
      assert status_id in status_ids
    end

    test "new status is added before DONE status", %{conn: conn, list: list} do
      response =
        conn
        |> post(~p"/api/boards/#{list.id}/statuses", %{name: "Review", color: "#8b5cf6"})
        |> json_response(201)

      # Should be position 2 (before done which gets bumped to 3)
      # todo=0, doing=1, new=2, done=3
      assert response["data"]["position"] == 2
    end

    test "returns error with empty name", %{conn: conn, list: list} do
      response =
        conn
        |> post(~p"/api/boards/#{list.id}/statuses", %{name: "", color: "#8b5cf6"})
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns error with invalid color format", %{conn: conn, list: list} do
      response =
        conn
        |> post(~p"/api/boards/#{list.id}/statuses", %{name: "Review", color: "invalid"})
        |> json_response(422)

      assert response["errors"]["color"]
    end

    test "returns error with duplicate name in same list", %{conn: conn, list: list} do
      # First create a status that will be uppercased
      conn
      |> post(~p"/api/boards/#{list.id}/statuses", %{name: "review", color: "#8b5cf6"})
      |> json_response(201)

      # Try to create another with same name (case-insensitive due to uppercasing)
      response =
        conn
        |> post(~p"/api/boards/#{list.id}/statuses", %{name: "REVIEW", color: "#ef4444"})
        |> json_response(422)

      # Unique constraint on [:list_id, :name] puts error on first field
      assert response["errors"]["list_id"]
    end

    test "returns 404 for list from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)

      conn
      |> post(~p"/api/boards/#{other_list.id}/statuses", %{name: "Review", color: "#8b5cf6"})
      |> json_response(404)
    end
  end

  describe "update" do
    test "updates status name", %{conn: conn, todo_status: todo_status} do
      response =
        conn
        |> patch(~p"/api/statuses/#{todo_status.id}", %{name: "Backlog"})
        |> json_response(200)

      # Name is uppercased on save
      assert response["data"]["name"] == "BACKLOG"
      assert response["data"]["color"] == todo_status.color
    end

    test "updates status color", %{conn: conn, todo_status: todo_status} do
      response =
        conn
        |> patch(~p"/api/statuses/#{todo_status.id}", %{color: "#ef4444"})
        |> json_response(200)

      assert response["data"]["color"] == "#ef4444"
      assert response["data"]["name"] == todo_status.name
    end

    test "updates both name and color", %{conn: conn, todo_status: todo_status} do
      response =
        conn
        |> patch(~p"/api/statuses/#{todo_status.id}", %{name: "Backlog", color: "#ef4444"})
        |> json_response(200)

      # Name is uppercased on save
      assert response["data"]["name"] == "BACKLOG"
      assert response["data"]["color"] == "#ef4444"
    end

    test "returns error with empty name", %{conn: conn, todo_status: todo_status} do
      response =
        conn
        |> patch(~p"/api/statuses/#{todo_status.id}", %{name: ""})
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns error with invalid color", %{conn: conn, todo_status: todo_status} do
      response =
        conn
        |> patch(~p"/api/statuses/#{todo_status.id}", %{color: "not-a-color"})
        |> json_response(422)

      assert response["errors"]["color"]
    end

    test "returns 404 for non-existent status", %{conn: conn} do
      conn
      |> patch(~p"/api/statuses/00000000-0000-0000-0000-000000000000", %{name: "New"})
      |> json_response(404)
    end

    test "returns 404 for status from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)
      other_status = insert(:list_status, list_id: other_list.id, name: "other", position: 0)

      conn
      |> patch(~p"/api/statuses/#{other_status.id}", %{name: "Hacked"})
      |> json_response(404)
    end
  end

  describe "delete" do
    test "deletes non-done status", %{conn: conn, doing_status: doing_status} do
      conn
      |> delete(~p"/api/statuses/#{doing_status.id}")
      |> response(204)
    end

    test "deleted status no longer appears in index", %{
      conn: conn,
      list: list,
      doing_status: doing_status
    } do
      conn
      |> delete(~p"/api/statuses/#{doing_status.id}")
      |> response(204)

      index_response =
        conn
        |> get(~p"/api/boards/#{list.id}/statuses")
        |> json_response(200)

      status_ids = Enum.map(index_response["data"], & &1["id"])
      refute doing_status.id in status_ids
    end

    test "cannot delete DONE status", %{conn: conn, done_status: done_status} do
      response =
        conn
        |> delete(~p"/api/statuses/#{done_status.id}")
        |> json_response(422)

      assert response["error"] == "Cannot delete the DONE status."
    end

    test "cannot delete status with tasks", %{
      conn: conn,
      user: user,
      list: list,
      doing_status: doing_status
    } do
      # Create a task with doing status
      _task = insert(:task, list_id: list.id, status_id: doing_status.id, created_by_id: user.id)

      response =
        conn
        |> delete(~p"/api/statuses/#{doing_status.id}")
        |> json_response(422)

      assert response["error"] ==
               "Cannot delete status that has tasks. Move or delete the tasks first."
    end

    test "returns 404 for non-existent status", %{conn: conn} do
      conn
      |> delete(~p"/api/statuses/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 for status from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)
      other_status = insert(:list_status, list_id: other_list.id, name: "other", position: 0)

      conn
      |> delete(~p"/api/statuses/#{other_status.id}")
      |> json_response(404)
    end
  end

  describe "reorder" do
    test "reorders statuses with DONE at end", %{
      conn: conn,
      list: list,
      todo_status: todo_status,
      doing_status: doing_status,
      done_status: done_status
    } do
      # Reorder to: doing, todo, done (done must be last)
      new_order = [doing_status.id, todo_status.id, done_status.id]

      response =
        conn
        |> put(~p"/api/boards/#{list.id}/statuses/reorder", %{status_ids: new_order})
        |> json_response(200)

      positions = response["data"] |> Enum.sort_by(& &1["position"]) |> Enum.map(& &1["id"])
      assert positions == new_order
    end

    test "reordered statuses reflect in index", %{
      conn: conn,
      list: list,
      todo_status: todo_status,
      doing_status: doing_status,
      done_status: done_status
    } do
      # Reorder to: doing, todo, done (done must be last)
      new_order = [doing_status.id, todo_status.id, done_status.id]

      conn
      |> put(~p"/api/boards/#{list.id}/statuses/reorder", %{status_ids: new_order})
      |> json_response(200)

      index_response =
        conn
        |> get(~p"/api/boards/#{list.id}/statuses")
        |> json_response(200)

      positions = index_response["data"] |> Enum.sort_by(& &1["position"]) |> Enum.map(& &1["id"])
      assert positions == new_order
    end

    test "rejects reorder when DONE is not last", %{
      conn: conn,
      list: list,
      todo_status: todo_status,
      doing_status: doing_status,
      done_status: done_status
    } do
      # Try to reorder with done not at the end
      invalid_order = [done_status.id, todo_status.id, doing_status.id]

      response =
        conn
        |> put(~p"/api/boards/#{list.id}/statuses/reorder", %{status_ids: invalid_order})
        |> json_response(422)

      assert response["error"] == "The DONE status must always be at the end."
    end

    test "returns 404 for list from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)

      conn
      |> put(~p"/api/boards/#{other_list.id}/statuses/reorder", %{status_ids: []})
      |> json_response(404)
    end
  end
end
