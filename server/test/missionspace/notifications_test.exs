defmodule Missionspace.NotificationsTest do
  use Missionspace.DataCase

  alias Missionspace.Notifications

  describe "list_notifications/2" do
    test "orders rolled-up notifications by latest activity" do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      actor = insert(:user, workspace_id: workspace.id)
      older_channel = insert(:channel, workspace_id: workspace.id)
      newer_channel = insert(:channel, workspace_id: workspace.id)

      older_notification =
        insert(:notification,
          user_id: user.id,
          actor_id: actor.id,
          type: "comment",
          item_type: "channel",
          item_id: older_channel.id,
          read: false,
          context: %{channelId: older_channel.id}
        )

      newer_notification =
        insert(:notification,
          user_id: user.id,
          actor_id: actor.id,
          type: "comment",
          item_type: "channel",
          item_id: newer_channel.id,
          read: false,
          context: %{channelId: newer_channel.id}
        )

      {:ok, rolled_up_notification} =
        Notifications.upsert_notification(%{
          type: "comment",
          item_type: "channel",
          item_id: older_channel.id,
          thread_id: nil,
          latest_message_id: UUIDv7.generate(),
          user_id: user.id,
          actor_id: actor.id,
          context: %{channelId: older_channel.id}
        })

      notifications = Notifications.list_notifications(user.id).entries

      assert Enum.at(notifications, 0).id == older_notification.id
      assert Enum.at(notifications, 0).event_count == older_notification.event_count + 1
      assert Enum.at(notifications, 0).updated_at == rolled_up_notification.updated_at
      assert Enum.at(notifications, 1).id == newer_notification.id
    end
  end

  describe "mark_as_read/1" do
    test "preserves the last activity timestamp" do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      actor = insert(:user, workspace_id: workspace.id)

      notification =
        insert(:notification,
          user_id: user.id,
          actor_id: actor.id,
          read: false,
          updated_at: ~U[2026-03-06 12:00:00Z]
        )

      {:ok, marked_notification} = Notifications.mark_as_read(notification.id)
      {:ok, persisted_notification} = Notifications.get_notification(notification.id)

      assert marked_notification.read
      assert marked_notification.updated_at == notification.updated_at
      assert persisted_notification.read
      assert persisted_notification.updated_at == notification.updated_at
    end
  end

  describe "mark_all_as_read/1" do
    test "preserves notification activity timestamps" do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      actor = insert(:user, workspace_id: workspace.id)

      first_notification =
        insert(:notification,
          user_id: user.id,
          actor_id: actor.id,
          read: false,
          updated_at: ~U[2026-03-06 12:00:00Z]
        )

      second_notification =
        insert(:notification,
          user_id: user.id,
          actor_id: actor.id,
          read: false,
          updated_at: ~U[2026-03-06 12:05:00Z]
        )

      assert {2, nil} = Notifications.mark_all_as_read(user.id)

      {:ok, first_persisted_notification} = Notifications.get_notification(first_notification.id)

      {:ok, second_persisted_notification} =
        Notifications.get_notification(second_notification.id)

      assert first_persisted_notification.read
      assert first_persisted_notification.updated_at == first_notification.updated_at
      assert second_persisted_notification.read
      assert second_persisted_notification.updated_at == second_notification.updated_at
    end
  end
end
