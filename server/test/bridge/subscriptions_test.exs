defmodule Bridge.SubscriptionsTest do
  use Bridge.DataCase

  alias Bridge.Subscriptions

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)
    user2 = insert(:user, workspace_id: workspace.id)
    task_id = UUIDv7.generate()

    {:ok, workspace: workspace, user: user, user2: user2, task_id: task_id}
  end

  describe "subscribe/1" do
    test "subscribes a user to an item", %{workspace: workspace, user: user, task_id: task_id} do
      assert {:ok, subscription} =
               Subscriptions.subscribe(%{
                 item_type: "task",
                 item_id: task_id,
                 user_id: user.id,
                 workspace_id: workspace.id
               })

      assert subscription.item_type == "task"
      assert subscription.item_id == task_id
      assert subscription.user_id == user.id
    end

    test "is idempotent — subscribing twice does not error", %{
      workspace: workspace,
      user: user,
      task_id: task_id
    } do
      attrs = %{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      }

      assert {:ok, _sub1} = Subscriptions.subscribe(attrs)
      assert {:ok, _sub2} = Subscriptions.subscribe(attrs)

      # Only one subscription row exists
      assert length(Subscriptions.list_subscriber_ids("task", task_id)) == 1
    end

    test "validates item_type inclusion", %{workspace: workspace, user: user} do
      assert {:error, changeset} =
               Subscriptions.subscribe(%{
                 item_type: "invalid",
                 item_id: UUIDv7.generate(),
                 user_id: user.id,
                 workspace_id: workspace.id
               })

      assert errors_on(changeset)[:item_type]
    end
  end

  describe "unsubscribe/3" do
    test "removes a subscription", %{workspace: workspace, user: user, task_id: task_id} do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      assert {:ok, _} = Subscriptions.unsubscribe("task", task_id, user.id)
      refute Subscriptions.subscribed?("task", task_id, user.id)
    end

    test "returns error when not subscribed", %{user: user, task_id: task_id} do
      assert {:error, :not_found} = Subscriptions.unsubscribe("task", task_id, user.id)
    end
  end

  describe "subscribed?/3" do
    test "returns true when subscribed", %{workspace: workspace, user: user, task_id: task_id} do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      assert Subscriptions.subscribed?("task", task_id, user.id)
    end

    test "returns false when not subscribed", %{user: user, task_id: task_id} do
      refute Subscriptions.subscribed?("task", task_id, user.id)
    end
  end

  describe "list_subscriber_ids/2" do
    test "returns all subscriber IDs", %{
      workspace: workspace,
      user: user,
      user2: user2,
      task_id: task_id
    } do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user2.id,
        workspace_id: workspace.id
      })

      ids = Subscriptions.list_subscriber_ids("task", task_id)
      assert length(ids) == 2
      assert user.id in ids
      assert user2.id in ids
    end

    test "returns empty list when no subscribers", %{task_id: task_id} do
      assert Subscriptions.list_subscriber_ids("task", task_id) == []
    end
  end

  describe "list_subscribers/2" do
    test "returns subscriptions with users preloaded", %{
      workspace: workspace,
      user: user,
      task_id: task_id
    } do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      [subscription] = Subscriptions.list_subscribers("task", task_id)
      assert subscription.user.id == user.id
      assert subscription.user.name == user.name
    end
  end

  describe "delete_all_for_user/1" do
    test "removes all subscriptions for a user", %{workspace: workspace, user: user} do
      task1_id = UUIDv7.generate()
      task2_id = UUIDv7.generate()

      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task1_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task2_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      {count, _} = Subscriptions.delete_all_for_user(user.id)
      assert count == 2
      refute Subscriptions.subscribed?("task", task1_id, user.id)
      refute Subscriptions.subscribed?("task", task2_id, user.id)
    end
  end

  describe "delete_all_for_item/2" do
    test "removes all subscriptions for an item", %{
      workspace: workspace,
      user: user,
      user2: user2,
      task_id: task_id
    } do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user2.id,
        workspace_id: workspace.id
      })

      {count, _} = Subscriptions.delete_all_for_item("task", task_id)
      assert count == 2
      assert Subscriptions.list_subscriber_ids("task", task_id) == []
    end
  end

  describe "thread subscriptions" do
    test "supports thread item_type", %{workspace: workspace, user: user} do
      parent_message_id = UUIDv7.generate()

      assert {:ok, sub} =
               Subscriptions.subscribe(%{
                 item_type: "thread",
                 item_id: parent_message_id,
                 user_id: user.id,
                 workspace_id: workspace.id
               })

      assert sub.item_type == "thread"
      assert Subscriptions.subscribed?("thread", parent_message_id, user.id)
    end
  end
end
