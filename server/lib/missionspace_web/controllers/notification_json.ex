defmodule MissionspaceWeb.NotificationJSON do
  alias Missionspace.Notifications.Notification

  @doc """
  Renders a list of notifications.
  """
  def index(%{page: page}) do
    %{
      data: for(notification <- page.entries, do: data(notification)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def index(%{notifications: notifications}) do
    %{data: for(notification <- notifications, do: data(notification))}
  end

  @doc """
  Renders a single notification.
  """
  def show(%{notification: notification}) do
    %{data: data(notification)}
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%Notification{} = notification) do
    %{
      id: notification.id,
      type: notification.type,
      item_type: notification.item_type,
      item_id: notification.item_id,
      thread_id: notification.thread_id,
      latest_message_id: notification.latest_message_id,
      event_count: notification.event_count,
      entity_type: notification.entity_type,
      entity_id: notification.entity_id,
      context: notification.context,
      read: notification.read,
      user_id: notification.user_id,
      actor_id: notification.actor_id,
      actor_name:
        if(Ecto.assoc_loaded?(notification.actor), do: notification.actor.name, else: nil),
      actor_avatar:
        if(Ecto.assoc_loaded?(notification.actor), do: notification.actor.avatar, else: nil),
      inserted_at: notification.inserted_at,
      updated_at: notification.updated_at
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
