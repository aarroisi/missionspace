defmodule Missionspace.ListsTest do
  use Missionspace.DataCase
  import Missionspace.Factory

  alias Missionspace.Lists

  describe "reorder_task/3" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      list = insert(:list, workspace_id: workspace.id, created_by_id: user.id)

      # Create statuses for the list
      todo_status = insert(:list_status, list_id: list.id, name: "todo", position: 0)
      doing_status = insert(:list_status, list_id: list.id, name: "doing", position: 1)
      done_status = insert(:list_status, list_id: list.id, name: "done", position: 2)

      %{
        workspace: workspace,
        user: user,
        list: list,
        todo_status: todo_status,
        doing_status: doing_status,
        done_status: done_status
      }
    end

    test "moves task to beginning of column", %{
      list: list,
      user: user,
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

      {:ok, updated} = Lists.reorder_task(task2, 0)

      assert updated.position < task1.position
      assert updated.status_id == todo_status.id
    end

    test "moves task to end of column", %{list: list, user: user, todo_status: todo_status} do
      task1 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 1000
        )

      _task2 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 2000
        )

      task3 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 3000
        )

      # Move task1 to end (index 2, after task2 and task3)
      {:ok, updated} = Lists.reorder_task(task1, 2)

      assert updated.position > task3.position
      assert updated.status_id == todo_status.id
    end

    test "moves task between two tasks", %{list: list, user: user, todo_status: todo_status} do
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

      task3 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 3000
        )

      # Move task3 between task1 and task2 (index 1)
      {:ok, updated} = Lists.reorder_task(task3, 1)

      assert updated.position > task1.position
      assert updated.position < task2.position
      assert updated.status_id == todo_status.id
    end

    test "changes status when moving to different column", %{
      list: list,
      user: user,
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

      {:ok, updated} = Lists.reorder_task(task, 0, doing_status.id)

      assert updated.status_id == doing_status.id
      assert updated.position == 1000
    end

    test "moves task to empty column", %{
      list: list,
      user: user,
      todo_status: todo_status,
      done_status: done_status
    } do
      task =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 1000
        )

      {:ok, updated} = Lists.reorder_task(task, 0, done_status.id)

      assert updated.status_id == done_status.id
      assert updated.position == 1000
    end

    test "moves task from one column to another with existing tasks", %{
      list: list,
      user: user,
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

      # Move task_todo to doing column at index 1 (between task_doing1 and task_doing2)
      {:ok, updated} = Lists.reorder_task(task_todo, 1, doing_status.id)

      assert updated.status_id == doing_status.id
      assert updated.position > task_doing1.position
      assert updated.position < task_doing2.position
    end
  end

  describe "create_task/1 with position" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      list = insert(:list, workspace_id: workspace.id, created_by_id: user.id)

      # Create statuses for the list
      todo_status = insert(:list_status, list_id: list.id, name: "todo", position: 0)
      doing_status = insert(:list_status, list_id: list.id, name: "doing", position: 1)

      %{
        workspace: workspace,
        user: user,
        list: list,
        todo_status: todo_status,
        doing_status: doing_status
      }
    end

    test "assigns initial position to new task", %{
      list: list,
      user: user,
      todo_status: todo_status
    } do
      {:ok, task} =
        Lists.create_task(%{
          "title" => "New Task",
          "list_id" => list.id,
          "created_by_id" => user.id,
          "status_id" => todo_status.id
        })

      assert task.position == 1000
    end

    test "assigns position after existing tasks", %{
      list: list,
      user: user,
      todo_status: todo_status
    } do
      _existing =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 1000
        )

      {:ok, task} =
        Lists.create_task(%{
          "title" => "New Task",
          "list_id" => list.id,
          "created_by_id" => user.id,
          "status_id" => todo_status.id
        })

      assert task.position == 2000
    end

    test "assigns position based on status column", %{
      list: list,
      user: user,
      todo_status: todo_status,
      doing_status: doing_status
    } do
      _todo_task =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 1000
        )

      _doing_task =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: doing_status.id,
          position: 5000
        )

      {:ok, new_doing} =
        Lists.create_task(%{
          "title" => "New Doing Task",
          "list_id" => list.id,
          "created_by_id" => user.id,
          "status_id" => doing_status.id
        })

      # Should be after the doing task, not affected by todo task
      assert new_doing.position == 6000
    end
  end

  describe "list_tasks/2 ordering" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      list = insert(:list, workspace_id: workspace.id, created_by_id: user.id)

      # Create status for the list
      todo_status = insert(:list_status, list_id: list.id, name: "todo", position: 0)

      %{workspace: workspace, user: user, list: list, todo_status: todo_status}
    end

    test "returns tasks ordered by position", %{list: list, user: user, todo_status: todo_status} do
      task3 =
        insert(:task,
          list_id: list.id,
          created_by_id: user.id,
          status_id: todo_status.id,
          position: 3000
        )

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

      page = Lists.list_tasks(list.id)
      task_ids = Enum.map(page.entries, & &1.id)

      assert task_ids == [task1.id, task2.id, task3.id]
    end
  end
end
