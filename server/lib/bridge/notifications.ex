defmodule Bridge.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo

  alias Bridge.Notifications.Notification

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
    |> order_by([n], asc: n.read, desc: n.id)
    |> preload([:user, :actor])
    |> Repo.paginate(
      Keyword.merge([cursor_fields: [{:read, :asc}, {:id, :desc}], limit: 50], opts)
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
        notification
        |> Notification.mark_as_read_changeset()
        |> Repo.update()

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
        notification
        |> Notification.mark_as_read_changeset()
        |> Repo.update()

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
    |> Repo.update_all(set: [read: true, updated_at: DateTime.utc_now()])
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
end
