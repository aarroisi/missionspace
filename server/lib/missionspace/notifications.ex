defmodule Missionspace.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Missionspace.Repo

  alias Missionspace.Notifications.Notification

  @doc """
  Returns the list of notifications for a user, paginated.
  Unread notifications are returned first, ordered by most recent.

  ## Options
    - `:limit` - The maximum number of notifications to return (default: 50)
    - `:after` - Cursor for pagination
    - `:before` - Cursor for pagination

  ## Examples

      iex> list_notifications(user_id)
      %{entries: [%Notification{}, ...], metadata: %{}}

  """
  def list_notifications(user_id, opts \\ []) do
    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by([n], asc: n.read, desc: n.updated_at, desc: n.id)
    |> preload([:user, :actor])
    |> Repo.paginate(
      Keyword.merge(
        [cursor_fields: [{:read, :asc}, {:updated_at, :desc}, {:id, :desc}], limit: 50],
        opts
      )
    )
  end

  @doc """
  Gets a single notification.

  Returns `{:ok, notification}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_notification(123)
      {:ok, %Notification{}}

      iex> get_notification(456)
      {:error, :not_found}

  """
  def get_notification(id) do
    case Notification
         |> preload([:user, :actor])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      notification -> {:ok, notification}
    end
  end

  @doc """
  Gets a notification for a specific user.

  Returns `{:ok, notification}` if found and belongs to user, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_notification(123, user_id)
      {:ok, %Notification{}}

      iex> get_notification(456, user_id)
      {:error, :not_found}

  """
  def get_notification(id, user_id) do
    case Notification
         |> where([n], n.user_id == ^user_id)
         |> preload([:user, :actor])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      notification -> {:ok, notification}
    end
  end

  @doc """
  Creates a notification.

  ## Examples

      iex> create_notification(%{field: value})
      {:ok, %Notification{}}

      iex> create_notification(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Upserts a rolled-up notification.
  If a notification with the same (user_id, type, item_type, item_id, thread_id) exists,
  updates the actor, increments event_count, marks as unread, and updates context.
  Otherwise creates a new notification.

  ## Examples

      iex> upsert_notification(%{type: "comment", item_type: "task", item_id: id, ...})
      {:ok, %Notification{}}

  """
  def upsert_notification(attrs) do
    thread_id = Map.get(attrs, :thread_id)

    # Build the conflict query with COALESCE for null thread_id
    conflict_query =
      if thread_id do
        from(n in Notification,
          where:
            n.user_id == ^attrs.user_id and
              n.type == ^attrs.type and
              n.item_type == ^attrs.item_type and
              n.item_id == ^attrs.item_id and
              n.thread_id == ^thread_id
        )
      else
        from(n in Notification,
          where:
            n.user_id == ^attrs.user_id and
              n.type == ^attrs.type and
              n.item_type == ^attrs.item_type and
              n.item_id == ^attrs.item_id and
              is_nil(n.thread_id)
        )
      end

    case Repo.one(conflict_query) do
      nil ->
        create_notification(attrs)

      existing ->
        existing
        |> Ecto.Changeset.change(%{
          actor_id: attrs.actor_id,
          latest_message_id: Map.get(attrs, :latest_message_id),
          event_count: existing.event_count + 1,
          context: Map.get(attrs, :context, existing.context),
          read: false,
          updated_at: DateTime.utc_now()
        })
        |> Repo.update()
    end
  end

  @doc """
  Marks a notification as read.

  ## Examples

      iex> mark_as_read(notification_id)
      {:ok, %Notification{}}

      iex> mark_as_read(invalid_id)
      {:error, :not_found}

  """
  def mark_as_read(id) do
    case get_notification(id) do
      {:ok, notification} ->
        mark_notification_as_read(notification)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Marks a notification as read for a specific user.

  ## Examples

      iex> mark_as_read(notification_id, user_id)
      {:ok, %Notification{}}

      iex> mark_as_read(invalid_id, user_id)
      {:error, :not_found}

  """
  def mark_as_read(id, user_id) do
    case get_notification(id, user_id) do
      {:ok, notification} ->
        mark_notification_as_read(notification)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Marks all notifications as read for a user.

  ## Examples

      iex> mark_all_as_read(user_id)
      {count, nil}

  """
  def mark_all_as_read(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and n.read == false)
    |> Repo.update_all(set: [read: true])
  end

  @doc """
  Gets the count of unread notifications for a user.

  ## Examples

      iex> get_unread_count(user_id)
      5

  """
  def get_unread_count(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and n.read == false)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Deletes a notification.

  ## Examples

      iex> delete_notification(notification)
      {:ok, %Notification{}}

  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification changes.

  ## Examples

      iex> change_notification(notification)
      %Ecto.Changeset{data: %Notification{}}

  """
  def change_notification(%Notification{} = notification, attrs \\ %{}) do
    Notification.changeset(notification, attrs)
  end

  @doc """
  Deletes all notifications for a user (both as recipient and actor).
  Used when soft-deleting a user.
  """
  def delete_all_for_user(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id or n.actor_id == ^user_id)
    |> Repo.delete_all()
  end

  defp mark_notification_as_read(notification) do
    {count, _} =
      Notification
      |> where([n], n.id == ^notification.id)
      |> Repo.update_all(set: [read: true])

    if count == 1 do
      {:ok, %{notification | read: true}}
    else
      {:error, :not_found}
    end
  end
end
