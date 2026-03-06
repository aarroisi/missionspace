defmodule MissionspaceWeb.TaskControllerTest do
  use MissionspaceWeb.ConnCase

  alias Missionspace.{Notifications, Subscriptions}

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)
    project = insert(:project, workspace_id: workspace.id)
    list = insert(:list, workspace_id: workspace.id)

    # Create default statuses for the list
    todo_status =
      insert(:list_status, list_id: list.id, name: "todo", color: "#6b7280", position: 0)

    doing_status =
      insert(:list_status, list_id: list.id, name: "doing", color: "#3b82f6", position: 1)

    done_status =
      insert(:list_status, list_id: list.id, name: "done", color: "#22c55e", position: 2)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok,
     conn: conn,
     workspace: workspace,
     user: user,
     project: project,
     list: list,
     todo_status: todo_status,
     doing_status: doing_status,
     done_status: done_status}
  end

  describe "index" do
    test "returns all tasks in list", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task1 = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)
      task2 = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      response =
        conn
        |> get(~p"/api/tasks?list_id=#{list.id}")
        |> json_response(200)

      task_ids = Enum.map(response["data"], & &1["id"])
      assert task1.id in task_ids
      assert task2.id in task_ids
    end

    test "does not return tasks from other lists", %{
      conn: conn,
      user: user,
      workspace: workspace,
      list: list,
      todo_status: todo_status
    } do
      other_list = insert(:list, workspace_id: workspace.id)
      other_status = insert(:list_status, list_id: other_list.id, name: "todo", position: 0)

      _task_in_list =
        insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      other_task =
        insert(:task, list_id: other_list.id, status_id: other_status.id, created_by_id: user.id)

      response =
        conn
        |> get(~p"/api/tasks?list_id=#{list.id}")
        |> json_response(200)

      task_ids = Enum.map(response["data"], & &1["id"])
      refute other_task.id in task_ids
    end

    test "returns empty list when no tasks exist", %{conn: conn, list: list} do
      response =
        conn
        |> get(~p"/api/tasks?list_id=#{list.id}")
        |> json_response(200)

      assert response["data"] == []
    end

    test "returns empty list when no list_id provided", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/tasks")
        |> json_response(200)

      assert response["data"] == []
    end

    test "returns paginated results with correct metadata", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      # Create 5 tasks
      for _ <- 1..5 do
        insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)
      end

      response =
        conn
        |> get(~p"/api/tasks?list_id=#{list.id}&limit=2")
        |> json_response(200)

      assert length(response["data"]) == 2
      assert response["metadata"]["limit"] == 2
      assert is_binary(response["metadata"]["after"]) or is_nil(response["metadata"]["after"])
      assert is_nil(response["metadata"]["before"])
    end
  end

  describe "create" do
    test "creates task with valid attributes using flat params", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      response =
        conn
        |> post(~p"/api/tasks", %{
          title: "New Task",
          status_id: todo_status.id,
          notes: "Some notes",
          list_id: list.id
        })
        |> json_response(201)

      assert response["data"]["title"] == "New Task"
      assert response["data"]["status"]["id"] == todo_status.id
      assert response["data"]["status"]["name"] == "todo"
      assert response["data"]["notes"] == "Some notes"
      assert response["data"]["board_id"] == list.id
      assert response["data"]["created_by_id"] == user.id
      assert response["data"]["id"]
      assert response["data"]["position"] == 1000
    end

    test "creates task with minimal required attributes", %{
      conn: conn,
      list: list,
      todo_status: todo_status
    } do
      response =
        conn
        |> post(~p"/api/tasks", %{title: "Simple Task", list_id: list.id})
        |> json_response(201)

      assert response["data"]["title"] == "Simple Task"
      # Should default to first status (todo)
      assert response["data"]["status"]["id"] == todo_status.id
      assert response["data"]["id"]
    end

    test "created task appears in index", %{conn: conn, list: list} do
      create_response =
        conn
        |> post(~p"/api/tasks", %{title: "Test Task", list_id: list.id})
        |> json_response(201)

      task_id = create_response["data"]["id"]

      index_response =
        conn
        |> get(~p"/api/tasks?list_id=#{list.id}")
        |> json_response(200)

      task_ids = Enum.map(index_response["data"], & &1["id"])
      assert task_id in task_ids
    end

    test "returns error with invalid attributes", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/tasks", %{title: ""})
        |> json_response(422)

      assert response["errors"]["title"] || response["errors"]["list_id"]
    end

    test "returns error with invalid status_id", %{conn: conn, list: list} do
      response =
        conn
        |> post(~p"/api/tasks", %{
          title: "Task",
          status_id: "00000000-0000-0000-0000-000000000000",
          list_id: list.id
        })
        |> json_response(422)

      assert response["errors"]["status_id"]
    end

    test "sets created_by_id to current user", %{conn: conn, user: user, list: list} do
      response =
        conn
        |> post(~p"/api/tasks", %{title: "Test Task", list_id: list.id})
        |> json_response(201)

      assert response["data"]["created_by_id"] == user.id
    end
  end

  describe "show" do
    test "returns task by id", %{conn: conn, user: user, list: list, doing_status: doing_status} do
      task =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: doing_status.id,
          title: "Test Task"
        )

      response =
        conn
        |> get(~p"/api/tasks/#{task.id}")
        |> json_response(200)

      assert response["data"]["id"] == task.id
      assert response["data"]["title"] == "Test Task"
      assert response["data"]["status"]["id"] == doing_status.id
      assert response["data"]["status"]["name"] == "doing"
      assert response["data"]["board_id"] == list.id
    end

    test "returns 404 for non-existent task", %{conn: conn} do
      conn
      |> get(~p"/api/tasks/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end
  end

  describe "update" do
    test "updates task with valid attributes using flat params", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status,
      done_status: done_status
    } do
      task =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          title: "Old Title"
        )

      response =
        conn
        |> put(~p"/api/tasks/#{task.id}", %{title: "New Title", status_id: done_status.id})
        |> json_response(200)

      assert response["data"]["title"] == "New Title"
      assert response["data"]["status"]["id"] == done_status.id
    end

    test "updates task notes", %{conn: conn, user: user, list: list, todo_status: todo_status} do
      task = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      response =
        conn
        |> put(~p"/api/tasks/#{task.id}", %{notes: "Updated notes"})
        |> json_response(200)

      assert response["data"]["notes"] == "Updated notes"
    end

    test "creates mention notification and subscription when notes add a new mention", %{
      conn: conn,
      workspace: workspace,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      mentioned_user = insert(:user, workspace_id: workspace.id, role: "member")

      task =
        insert(:task,
          list_id: list.id,
          status_id: todo_status.id,
          created_by_id: user.id,
          notes: "Initial notes"
        )

      notes = "Loop in @[#{mentioned_user.name}](member:#{mentioned_user.id})"

      response =
        conn
        |> put(~p"/api/tasks/#{task.id}", %{notes: notes})
        |> json_response(200)

      assert response["data"]["notes"] == notes
      assert Subscriptions.subscribed?("task", task.id, mentioned_user.id)

      notifications = Notifications.list_notifications(mentioned_user.id).entries

      assert Enum.any?(notifications, fn notification ->
               notification.type == "mention" and
                 notification.item_type == "task" and
                 notification.item_id == task.id and
                 notification.actor_id == user.id
             end)
    end

    test "does not create mention notification for self-mention in notes", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)
      notes = "Self mention @[#{user.name}](member:#{user.id})"

      conn
      |> put(~p"/api/tasks/#{task.id}", %{notes: notes})
      |> json_response(200)

      notifications = Notifications.list_notifications(user.id).entries

      refute Enum.any?(notifications, fn notification ->
               notification.type == "mention" and notification.item_id == task.id
             end)
    end

    test "does not re-notify existing mentions when editing notes", %{
      conn: conn,
      workspace: workspace,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      mentioned_user = insert(:user, workspace_id: workspace.id, role: "member")

      task =
        insert(:task,
          list_id: list.id,
          status_id: todo_status.id,
          created_by_id: user.id,
          notes: "Initial notes"
        )

      mention = "@[#{mentioned_user.name}](member:#{mentioned_user.id})"

      conn
      |> put(~p"/api/tasks/#{task.id}", %{notes: "First pass #{mention}"})
      |> json_response(200)

      conn
      |> put(~p"/api/tasks/#{task.id}", %{notes: "First pass #{mention}\n\nMore details"})
      |> json_response(200)

      mention_notifications =
        Notifications.list_notifications(mentioned_user.id).entries
        |> Enum.filter(fn notification ->
          notification.type == "mention" and notification.item_type == "task" and
            notification.item_id == task.id
        end)

      assert length(mention_notifications) == 1
    end

    test "updated task reflects changes in show", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task =
        insert(:task,
          list_id: list.id,
          status_id: todo_status.id,
          created_by_id: user.id,
          title: "Old Title"
        )

      conn
      |> put(~p"/api/tasks/#{task.id}", %{title: "Updated Title"})
      |> json_response(200)

      show_response =
        conn
        |> get(~p"/api/tasks/#{task.id}")
        |> json_response(200)

      assert show_response["data"]["title"] == "Updated Title"
    end

    test "returns error with invalid attributes", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      response =
        conn
        |> put(~p"/api/tasks/#{task.id}", %{title: ""})
        |> json_response(422)

      assert response["errors"]["title"]
    end

    test "returns error with invalid status_id", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      response =
        conn
        |> put(~p"/api/tasks/#{task.id}", %{status_id: "00000000-0000-0000-0000-000000000000"})
        |> json_response(422)

      assert response["errors"]["status_id"]
    end

    test "returns 404 for non-existent task", %{conn: conn} do
      conn
      |> put(~p"/api/tasks/00000000-0000-0000-0000-000000000000", %{title: "New Title"})
      |> json_response(404)
    end
  end

  describe "delete" do
    test "deletes task", %{conn: conn, user: user, list: list, todo_status: todo_status} do
      task = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      conn
      |> delete(~p"/api/tasks/#{task.id}")
      |> response(204)
    end

    test "deleted task no longer appears in index", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      conn
      |> delete(~p"/api/tasks/#{task.id}")
      |> response(204)

      index_response =
        conn
        |> get(~p"/api/tasks?list_id=#{list.id}")
        |> json_response(200)

      task_ids = Enum.map(index_response["data"], & &1["id"])
      refute task.id in task_ids
    end

    test "deleted task returns 404 on show", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task = insert(:task, list_id: list.id, status_id: todo_status.id, created_by_id: user.id)

      conn
      |> delete(~p"/api/tasks/#{task.id}")
      |> response(204)

      conn
      |> get(~p"/api/tasks/#{task.id}")
      |> json_response(404)
    end

    test "returns 404 for non-existent task", %{conn: conn} do
      conn
      |> delete(~p"/api/tasks/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end
  end

  describe "reorder" do
    test "reorders task within same column", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status
    } do
      task1 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 1000
        )

      task2 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 2000
        )

      # Move task2 to position 0 (before task1)
      response =
        conn
        |> put(~p"/api/tasks/#{task2.id}/reorder", %{position: 0})
        |> json_response(200)

      assert response["data"]["position"] < task1.position
      assert response["data"]["status"]["id"] == todo_status.id
    end

    test "moves task to different column", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status,
      doing_status: doing_status
    } do
      task =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 1000
        )

      response =
        conn
        |> put(~p"/api/tasks/#{task.id}/reorder", %{position: 0, status_id: doing_status.id})
        |> json_response(200)

      assert response["data"]["status"]["id"] == doing_status.id
    end

    test "moves task between two tasks in another column", %{
      conn: conn,
      user: user,
      list: list,
      todo_status: todo_status,
      doing_status: doing_status
    } do
      task_todo =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 1000
        )

      task_doing1 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: doing_status.id,
          position: 1000
        )

      task_doing2 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: doing_status.id,
          position: 2000
        )

      # Move task_todo to doing column at index 1 (between doing1 and doing2)
      response =
        conn
        |> put(~p"/api/tasks/#{task_todo.id}/reorder", %{position: 1, status_id: doing_status.id})
        |> json_response(200)

      assert response["data"]["status"]["id"] == doing_status.id
      assert response["data"]["position"] > task_doing1.position
      assert response["data"]["position"] < task_doing2.position
    end

    test "returns 404 for non-existent task", %{conn: conn} do
      conn
      |> put(~p"/api/tasks/00000000-0000-0000-0000-000000000000/reorder", %{position: 0})
      |> json_response(404)
    end
  end
end
