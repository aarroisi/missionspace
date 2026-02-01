defmodule Bridge.Mentions do
  @moduledoc """
  Helper module for extracting and processing mentions from message text.
  """

  alias Bridge.Notifications

  @doc """
  Extracts user IDs from mentions in HTML text.
  Mentions are in the format: <span class="mention" data-id="user-uuid">@Name</span>

  ## Examples

      iex> extract_mention_ids("<p>Hello <span class=\"mention\" data-id=\"abc-123\">@John</span></p>")
      ["abc-123"]

  """
  def extract_mention_ids(text) when is_binary(text) do
    # Match data-id="..." in mention spans
    regex = ~r/data-id="([^"]+)"/

    regex
    |> Regex.scan(text)
    |> Enum.map(fn [_full, id] -> id end)
    |> Enum.uniq()
  end

  def extract_mention_ids(_), do: []

  @doc """
  Creates notifications for all mentioned users in a message.
  Returns a list of created notification results.

  ## Parameters
    - message: The message struct containing the text with mentions
    - actor_id: The ID of the user who sent the message (who did the mentioning)
    - context: Additional context to include in the notification (e.g., channel_name, task_title)

  ## Examples

      iex> create_notifications_for_mentions(message, actor_id, %{channel_name: "general"})
      [{:ok, %Notification{}}, ...]

  """
  def create_notifications_for_mentions(message, actor_id, context \\ %{}) do
    mentioned_user_ids = extract_mention_ids(message.text)

    # Don't notify the author if they mention themselves
    mentioned_user_ids = Enum.reject(mentioned_user_ids, &(&1 == actor_id))

    Enum.map(mentioned_user_ids, fn user_id ->
      result =
        Notifications.create_notification(%{
          type: "mention",
          entity_type: message.entity_type,
          entity_id: message.id,
          user_id: user_id,
          actor_id: actor_id,
          context: context
        })

      # Broadcast to user's notification channel
      case result do
        {:ok, notification} ->
          notification = Bridge.Repo.preload(notification, [:actor])
          broadcast_notification(notification)
          result

        _ ->
          result
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
        entity_type: notification.entity_type,
        entity_id: notification.entity_id,
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

  ## Examples

      iex> build_notification_context(message, workspace_id)
      %{channel_id: "...", channel_name: "general"}

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
            %{
              taskId: message.entity_id,
              taskTitle: task.title,
              boardId: task.list_id
            }

          _ ->
            %{taskId: message.entity_id}
        end

      "subtask" ->
        case Bridge.Lists.get_subtask(message.entity_id) do
          {:ok, subtask} ->
            task_result = Bridge.Lists.get_task(subtask.task_id)

            base = %{
              subtaskId: message.entity_id,
              subtaskTitle: subtask.title,
              taskId: subtask.task_id
            }

            case task_result do
              {:ok, task} ->
                base
                |> Map.put(:boardId, task.list_id)
                |> Map.put(:taskTitle, task.title)

              _ ->
                base
            end

          _ ->
            %{subtaskId: message.entity_id}
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
