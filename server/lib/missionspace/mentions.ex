defmodule Missionspace.Mentions do
  @moduledoc """
  Orchestrates notifications for new messages.
  Handles subscription-based notifications, thread isolation, rollup, and @mentions.
  """

  alias Missionspace.{Notifications, Subscriptions, Repo}

  @doc """
  Extracts user IDs from mention markup in content.

  Supports both:
  - Markdown mentions: @[Name](member:user-uuid)
  - Legacy HTML mentions: <span class="mention" data-id="user-uuid">@Name</span>

  ## Examples

      iex> extract_mention_ids("<p>Hello <span class=\\"mention\\" data-id=\\"abc-123\\">@John</span></p>")
      ["abc-123"]

  """
  @html_mention_regex ~r/data-id="([^"]+)"/
  @markdown_mention_regex ~r/\(member:([^)]+)\)/

  def extract_mention_ids(text) when is_binary(text) do
    (extract_ids(@html_mention_regex, text) ++ extract_ids(@markdown_mention_regex, text))
    |> Enum.uniq()
  end

  def extract_mention_ids(_), do: []

  defp extract_ids(regex, text) do
    regex
    |> Regex.scan(text)
    |> Enum.map(fn [_full, id] -> id end)
  end

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
      case Missionspace.Chat.get_direct_message(message.entity_id, workspace_id) do
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
  Broadcasts a notification to the user's notification channel and sends web push.
  """
  def broadcast_notification(notification) do
    data = %{
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

    MissionspaceWeb.NotificationChannel.broadcast_notification(notification.user_id, data)

    # Send web push notification (fire-and-forget, errors won't block)
    try do
      actor_name = data[:actor_name] || "Someone"
      frontend_url = Application.get_env(:missionspace, :frontend_url, "https://missionspace.co")

      Missionspace.PushNotifications.send_web_push(notification.user_id, %{
        title: push_title(notification.type, notification.item_type, actor_name),
        body: push_body(notification.type, notification.item_type, actor_name),
        data: %{url: build_notification_url(frontend_url, data)}
      })
    rescue
      _ -> :ok
    end
  end

  defp push_title(type, item_type, actor_name) do
    case type do
      "mention" -> "#{actor_name} mentioned you"
      "thread_reply" -> "#{actor_name} replied in a thread"
      "comment" -> "#{actor_name} commented on a #{item_type}"
      _ -> "New notification"
    end
  end

  defp push_body(type, item_type, _actor_name) do
    case {type, item_type} do
      {"mention", "channel"} -> "You were mentioned in a channel"
      {"mention", "dm"} -> "You were mentioned in a message"
      {"mention", "task"} -> "You were mentioned on a task"
      {"mention", "doc"} -> "You were mentioned on a doc"
      {"thread_reply", _} -> "New reply in a thread you're following"
      {"comment", "channel"} -> "New message in a channel you're following"
      {"comment", "dm"} -> "New direct message"
      {"comment", "task"} -> "New comment on a task you're following"
      {"comment", "doc"} -> "New comment on a doc you're following"
      _ -> "You have a new notification"
    end
  end

  defp build_notification_url(frontend_url, data) do
    context = data[:context] || %{}

    path =
      case data[:item_type] do
        "channel" ->
          if channel_id = context[:channelId], do: "/channels/#{channel_id}", else: "/dashboard"

        "dm" ->
          if dm_id = context[:dmId], do: "/dms/#{dm_id}", else: "/dashboard"

        "task" ->
          if board_id = context[:boardId] do
            "/boards/#{board_id}?task=#{data[:item_id]}"
          else
            "/dashboard"
          end

        "doc" ->
          if doc_id = context[:docId], do: "/docs/#{doc_id}", else: "/dashboard"

        _ ->
          "/dashboard"
      end

    "#{frontend_url}#{path}"
  end

  @doc """
  Builds context for a notification based on the message's entity type.
  This provides information needed for navigation when the notification is clicked.
  """
  def build_notification_context(message, workspace_id) do
    case message.entity_type do
      "channel" ->
        case Missionspace.Chat.get_channel(message.entity_id, workspace_id) do
          {:ok, channel} -> %{channelId: message.entity_id, channelName: channel.name}
          _ -> %{channelId: message.entity_id}
        end

      "dm" ->
        %{dmId: message.entity_id}

      "task" ->
        case Missionspace.Lists.get_task(message.entity_id) do
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
        case Missionspace.Docs.get_doc(message.entity_id, workspace_id) do
          {:ok, doc} -> %{docId: message.entity_id, docTitle: doc.title}
          _ -> %{docId: message.entity_id}
        end

      _ ->
        %{}
    end
  end
end
