defmodule Bridge.Mentions do
  @moduledoc """
  Orchestrates notifications for new messages.
  Handles subscription-based notifications, thread isolation, rollup, and @mentions.
  """

  alias Bridge.{Notifications, Subscriptions, Repo}

  @doc """
  Extracts user IDs from mentions in markdown text.
  Mentions are in the format: <span class="mention" data-id="user-uuid">@Name</span>

  ## Examples

      iex> extract_mention_ids("<p>Hello <span class=\\"mention\\" data-id=\\"abc-123\\">@John</span></p>")
      ["abc-123"]

  """
  def extract_mention_ids(text) when is_binary(text) do
    regex = ~r/data-id="([^"]+)"/

    regex
    |> Regex.scan(text)
    |> Enum.map(fn [_full, id] -> id end)
    |> Enum.uniq()
  end

  def extract_mention_ids(_), do: []

  @doc """
  Main entry point: notifies subscribers and mentioned users for a new message.

  Thread replies only notify thread subscribers, NOT item-level subscribers.
  Top-level messages notify item subscribers.
  @mentions always create a separate notification regardless of subscription status.

  ## Parameters
    - message: The message struct (with `parent_id`, `entity_type`, `entity_id`, `text`, `id`)
    - actor_id: The user who sent the message
    - workspace_id: The workspace for subscription context
  """
  def notify_for_new_message(message, actor_id, workspace_id) do
    mentioned_user_ids =
      message.text
      |> extract_mention_ids()
      |> Enum.reject(&(&1 == actor_id))

    context = build_notification_context(message, workspace_id)

    if message.parent_id do
      notify_thread_reply(message, actor_id, workspace_id, mentioned_user_ids, context)
    else
      notify_top_level(message, actor_id, workspace_id, mentioned_user_ids, context)
    end
  end

  # Thread reply: notify thread subscribers only, not item-level subscribers
  defp notify_thread_reply(message, actor_id, workspace_id, mentioned_user_ids, context) do
    # Auto-subscribe actor to the thread
    Subscriptions.subscribe(%{
      item_type: "thread",
      item_id: message.parent_id,
      user_id: actor_id,
      workspace_id: workspace_id
    })

    # Auto-subscribe mentioned users to the thread
    Enum.each(mentioned_user_ids, fn user_id ->
      Subscriptions.subscribe(%{
        item_type: "thread",
        item_id: message.parent_id,
        user_id: user_id,
        workspace_id: workspace_id
      })
    end)

    # Get thread subscriber IDs
    subscriber_ids =
      Subscriptions.list_subscriber_ids("thread", message.parent_id)
      |> Enum.reject(&(&1 == actor_id))

    # Upsert "thread_reply" notification for each subscriber (excluding actor)
    Enum.each(subscriber_ids, fn user_id ->
      {:ok, notification} =
        Notifications.upsert_notification(%{
          type: "thread_reply",
          item_type: message.entity_type,
          item_id: message.entity_id,
          thread_id: message.parent_id,
          latest_message_id: message.id,
          user_id: user_id,
          actor_id: actor_id,
          context: context
        })

      notification = Repo.preload(notification, [:actor])
      broadcast_notification(notification)
    end)

    # Create separate "mention" notifications
    create_mention_notifications(message, actor_id, mentioned_user_ids, context)
  end

  # Top-level message: notify item subscribers
  defp notify_top_level(message, actor_id, workspace_id, mentioned_user_ids, context) do
    item_type = message.entity_type

    # For DMs, auto-subscribe both participants (DMs are always implicit)
    if item_type == "dm" do
      case Bridge.Chat.get_direct_message(message.entity_id, workspace_id) do
        {:ok, dm} ->
          Enum.each([dm.user1_id, dm.user2_id], fn user_id ->
            Subscriptions.subscribe(%{
              item_type: item_type,
              item_id: message.entity_id,
              user_id: user_id,
              workspace_id: workspace_id
            })
          end)

        _ ->
          :ok
      end
    else
      # Auto-subscribe actor to the item
      Subscriptions.subscribe(%{
        item_type: item_type,
        item_id: message.entity_id,
        user_id: actor_id,
        workspace_id: workspace_id
      })
    end

    # Auto-subscribe mentioned users to the item
    Enum.each(mentioned_user_ids, fn user_id ->
      Subscriptions.subscribe(%{
        item_type: item_type,
        item_id: message.entity_id,
        user_id: user_id,
        workspace_id: workspace_id
      })
    end)

    # Get item subscriber IDs
    subscriber_ids =
      Subscriptions.list_subscriber_ids(item_type, message.entity_id)
      |> Enum.reject(&(&1 == actor_id))

    # Upsert "comment" notification for each subscriber (excluding actor)
    Enum.each(subscriber_ids, fn user_id ->
      {:ok, notification} =
        Notifications.upsert_notification(%{
          type: "comment",
          item_type: item_type,
          item_id: message.entity_id,
          thread_id: nil,
          latest_message_id: message.id,
          user_id: user_id,
          actor_id: actor_id,
          context: context
        })

      notification = Repo.preload(notification, [:actor])
      broadcast_notification(notification)
    end)

    # Create separate "mention" notifications
    create_mention_notifications(message, actor_id, mentioned_user_ids, context)
  end

  # Creates separate "mention" notifications for mentioned users
  defp create_mention_notifications(message, actor_id, mentioned_user_ids, context) do
    Enum.each(mentioned_user_ids, fn user_id ->
      result =
        Notifications.create_notification(%{
          type: "mention",
          item_type: message.entity_type,
          item_id: message.entity_id,
          thread_id: message.parent_id,
          latest_message_id: message.id,
          user_id: user_id,
          actor_id: actor_id,
          context: context
        })

      case result do
        {:ok, notification} ->
          notification = Repo.preload(notification, [:actor])
          broadcast_notification(notification)

        _ ->
          :ok
      end
    end)
  end

  @doc """
  Broadcasts a notification to the user's notification channel.
  """
  def broadcast_notification(notification) do
    BridgeWeb.NotificationChannel.broadcast_notification(
      notification.user_id,
      %{
        id: notification.id,
        type: notification.type,
        item_type: notification.item_type,
        item_id: notification.item_id,
        thread_id: notification.thread_id,
        latest_message_id: notification.latest_message_id,
        event_count: notification.event_count,
        context: notification.context,
        read: notification.read,
        user_id: notification.user_id,
        actor_id: notification.actor_id,
        actor_name: if(notification.actor, do: notification.actor.name, else: nil),
        actor_avatar: if(notification.actor, do: notification.actor.avatar, else: nil),
        inserted_at: notification.inserted_at,
        updated_at: notification.updated_at
      }
    )
  end

  @doc """
  Builds context for a notification based on the message's entity type.
  This provides information needed for navigation when the notification is clicked.
  """
  def build_notification_context(message, workspace_id) do
    case message.entity_type do
      "channel" ->
        case Bridge.Chat.get_channel(message.entity_id, workspace_id) do
          {:ok, channel} -> %{channelId: message.entity_id, channelName: channel.name}
          _ -> %{channelId: message.entity_id}
        end

      "dm" ->
        %{dmId: message.entity_id}

      "task" ->
        case Bridge.Lists.get_task(message.entity_id) do
          {:ok, task} ->
            base = %{
              taskId: message.entity_id,
              taskTitle: task.title,
              boardId: task.list_id
            }

            if task.parent_id do
              Map.put(base, :parentTaskId, task.parent_id)
            else
              base
            end

          _ ->
            %{taskId: message.entity_id}
        end

      "doc" ->
        case Bridge.Docs.get_doc(message.entity_id, workspace_id) do
          {:ok, doc} -> %{docId: message.entity_id, docTitle: doc.title}
          _ -> %{docId: message.entity_id}
        end

      _ ->
        %{}
    end
  end
end
