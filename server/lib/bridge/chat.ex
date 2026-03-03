defmodule Bridge.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo

  alias Bridge.Chat.{Channel, DirectMessage, Message, ReadPosition}

  # ============================================================================
  # Channel functions
  # ============================================================================

  @doc """
  Returns the list of channels for a workspace.

  ## Examples

      iex> list_channels(workspace_id, user)
      [%Channel{}, ...]

  """
  def list_channels(workspace_id, user, opts \\ []) do
    Channel
    |> where([c], c.workspace_id == ^workspace_id)
    |> filter_accessible_channels(user)
    |> order_by([c], desc: c.id)
    |> preload([:created_by])
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  def list_starred_channels(workspace_id, user, opts \\ []) do
    starred_ids = Bridge.Stars.starred_ids(user.id, "channel")

    if MapSet.size(starred_ids) == 0 do
      %{entries: [], metadata: %{after: nil, before: nil, limit: 50}}
    else
      ids = MapSet.to_list(starred_ids)

      Channel
      |> where([c], c.id in ^ids and c.workspace_id == ^workspace_id)
      |> filter_accessible_channels(user)
      |> order_by([c], desc: c.id)
      |> preload([:created_by])
      |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
    end
  end

  defp filter_accessible_channels(query, %{role: "owner", id: user_id}) do
    where(query, [c], c.visibility == "shared" or c.created_by_id == ^user_id)
  end

  defp filter_accessible_channels(query, %{id: user_id}) do
    project_channel_ids =
      Bridge.Projects.get_project_item_ids_for_user_projects(user_id, "channel")

    item_member_ids = Bridge.Projects.get_user_item_member_ids(user_id, "channel")

    where(
      query,
      [c],
      c.id in ^project_channel_ids or
        c.created_by_id == ^user_id or
        (c.visibility == "shared" and c.id in ^item_member_ids)
    )
  end

  @doc """
  Gets a single channel within a workspace.

  Returns `{:ok, channel}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_channel(id, workspace_id)
      {:ok, %Channel{}}

      iex> get_channel(456, workspace_id)
      {:error, :not_found}

  """
  def get_channel(id, workspace_id) do
    case Channel
         |> where([c], c.workspace_id == ^workspace_id)
         |> preload([:created_by])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      channel -> {:ok, channel}
    end
  end

  @doc """
  Creates a channel.

  ## Examples

      iex> create_channel(%{field: value})
      {:ok, %Channel{}}

      iex> create_channel(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a channel.

  ## Examples

      iex> update_channel(channel, %{field: new_value})
      {:ok, %Channel{}}

      iex> update_channel(channel, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.

  ## Examples

      iex> change_channel(channel)
      %Ecto.Changeset{data: %Channel{}}

  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end


  # ============================================================================
  # DirectMessage functions
  # ============================================================================

  @doc """
  Returns the list of direct messages for a workspace.

  ## Examples

      iex> list_direct_messages(workspace_id)
      [%DirectMessage{}, ...]

  """
  def list_direct_messages(workspace_id, opts \\ []) do
    DirectMessage
    |> where([dm], dm.workspace_id == ^workspace_id)
    |> order_by([dm], desc: dm.id)
    |> preload([:user1, :user2])
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  @doc """
  Returns the list of direct messages for a specific user.

  ## Examples

      iex> list_direct_messages_by_user(user_id)
      [%DirectMessage{}, ...]

  """
  def list_direct_messages_by_user(user_id, opts \\ []) do
    DirectMessage
    |> where([dm], dm.user1_id == ^user_id or dm.user2_id == ^user_id)
    |> order_by([dm], desc: dm.id)
    |> preload([:user1, :user2])
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  @doc """
  Returns the list of starred direct messages for a workspace.

  ## Examples

      iex> list_starred_direct_messages(workspace_id)
      [%DirectMessage{}, ...]

  """
  def list_starred_direct_messages(workspace_id, user_id, opts \\ []) do
    starred_ids = Bridge.Stars.starred_ids(user_id, "direct_message")

    if MapSet.size(starred_ids) == 0 do
      %{entries: [], metadata: %{after: nil, before: nil, limit: 50}}
    else
      ids = MapSet.to_list(starred_ids)

      DirectMessage
      |> where([dm], dm.id in ^ids and dm.workspace_id == ^workspace_id)
      |> order_by([dm], desc: dm.id)
      |> preload([:user1, :user2])
      |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
    end
  end

  @doc """
  Gets a single direct message within a workspace.

  Returns `{:ok, direct_message}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_direct_message(id, workspace_id)
      {:ok, %DirectMessage{}}

      iex> get_direct_message(456, workspace_id)
      {:error, :not_found}

  """
  def get_direct_message(id, workspace_id) do
    case DirectMessage
         |> where([dm], dm.workspace_id == ^workspace_id)
         |> preload([:user1, :user2])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      direct_message -> {:ok, direct_message}
    end
  end

  @doc """
  Gets a direct message between two users.

  Returns `nil` if the direct message does not exist.

  ## Examples

      iex> get_direct_message_between(user1_id, user2_id)
      %DirectMessage{}

      iex> get_direct_message_between(user1_id, user3_id)
      nil

  """
  def get_direct_message_between(user1_id, user2_id) do
    DirectMessage
    |> where(
      [dm],
      (dm.user1_id == ^user1_id and dm.user2_id == ^user2_id) or
        (dm.user1_id == ^user2_id and dm.user2_id == ^user1_id)
    )
    |> preload([:user1, :user2])
    |> Repo.one()
  end

  @doc """
  Creates a direct message.

  ## Examples

      iex> create_direct_message(%{field: value})
      {:ok, %DirectMessage{}}

      iex> create_direct_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_direct_message(attrs \\ %{}) do
    %DirectMessage{}
    |> DirectMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates or gets a direct message between two users.

  ## Examples

      iex> create_or_get_direct_message(user1_id, user2_id)
      {:ok, %DirectMessage{}}

  """
  def create_or_get_direct_message(user1_id, user2_id, workspace_id) do
    case get_direct_message_between(user1_id, user2_id) do
      nil ->
        create_direct_message(%{
          user1_id: user1_id,
          user2_id: user2_id,
          workspace_id: workspace_id
        })

      dm ->
        {:ok, dm}
    end
  end

  @doc """
  Updates a direct message.

  ## Examples

      iex> update_direct_message(direct_message, %{field: new_value})
      {:ok, %DirectMessage{}}

      iex> update_direct_message(direct_message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_direct_message(%DirectMessage{} = direct_message, attrs) do
    direct_message
    |> DirectMessage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a direct message.

  ## Examples

      iex> delete_direct_message(direct_message)
      {:ok, %DirectMessage{}}

      iex> delete_direct_message(direct_message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_direct_message(%DirectMessage{} = direct_message) do
    Repo.delete(direct_message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking direct message changes.

  ## Examples

      iex> change_direct_message(direct_message)
      %Ecto.Changeset{data: %DirectMessage{}}

  """
  def change_direct_message(%DirectMessage{} = direct_message, attrs \\ %{}) do
    DirectMessage.changeset(direct_message, attrs)
  end

  # ============================================================================
  # Message functions
  # ============================================================================

  @doc """
  Returns the list of messages.

  ## Examples

      iex> list_messages()
      [%Message{}, ...]

  """
  def list_messages(opts \\ []) do
    Message
    |> preload([:user, :parent, quote: [:user]])
    |> order_by([m], desc: m.id)
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  @doc """
  Returns the list of messages for a specific entity (task, doc, channel, or dm).

  ## Examples

      iex> list_messages_by_entity("channel", channel_id)
      [%Message{}, ...]

  """
  def list_messages_by_entity(entity_type, entity_id, opts \\ []) do
    Message
    |> where([m], m.entity_type == ^entity_type and m.entity_id == ^entity_id)
    |> preload([:user, :parent, quote: [:user]])
    |> order_by([m], desc: m.id)
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  @doc """
  Returns the list of messages sent by a specific user.

  ## Examples

      iex> list_messages_by_user(user_id)
      [%Message{}, ...]

  """
  def list_messages_by_user(user_id, opts \\ []) do
    Message
    |> where([m], m.user_id == ^user_id)
    |> preload([:user, :parent, quote: [:user]])
    |> order_by([m], desc: m.id)
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  @doc """
  Returns the list of reply messages for a specific parent message.

  ## Examples

      iex> list_message_replies(parent_id)
      [%Message{}, ...]

  """
  def list_message_replies(parent_id, opts \\ []) do
    Message
    |> where([m], m.parent_id == ^parent_id)
    |> preload([:user, :parent, quote: [:user]])
    |> order_by([m], desc: m.id)
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  @doc """
  Gets a single message.

  Returns `{:ok, message}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_message(123)
      {:ok, %Message{}}

      iex> get_message(456)
      {:error, :not_found}

  """
  def get_message(id) do
    case Message
         |> preload([:user, :parent, quote: [:user]])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  @doc """
  Creates a message.

  ## Examples

      iex> create_message(%{field: value})
      {:ok, %Message{}}

      iex> create_message(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a message for a specific entity.

  ## Examples

      iex> create_message_for_entity("channel", channel_id, user_id, "Hello!")
      {:ok, %Message{}}

  """
  def create_message_for_entity(entity_type, entity_id, user_id, text, opts \\ %{}) do
    attrs =
      %{
        entity_type: entity_type,
        entity_id: entity_id,
        user_id: user_id,
        text: text
      }
      |> Map.merge(opts)

    create_message(attrs)
  end

  @doc """
  Updates a message.

  ## Examples

      iex> update_message(message, %{field: new_value})
      {:ok, %Message{}}

      iex> update_message(message, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a message.

  ## Examples

      iex> delete_message(message)
      {:ok, %Message{}}

      iex> delete_message(message)
      {:error, %Ecto.Changeset{}}

  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.

  ## Examples

      iex> change_message(message)
      %Ecto.Changeset{data: %Message{}}

  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Updates the text of a message.

  ## Examples

      iex> update_message_text(message, "Updated text")
      {:ok, %Message{}}

  """
  def update_message_text(%Message{} = message, text) when is_binary(text) do
    update_message(message, %{text: text})
  end

  # ============================================================================
  # Read Position functions
  # ============================================================================

  @doc """
  Updates (upserts) the read position for a user on an item.
  Sets `last_read_at` to the current time.

  ## Examples

      iex> update_read_position("channel", channel_id, user_id)
      {:ok, %ReadPosition{}}

  """
  def update_read_position(item_type, item_id, user_id) do
    now = DateTime.utc_now()

    %ReadPosition{}
    |> ReadPosition.changeset(%{
      item_type: item_type,
      item_id: item_id,
      user_id: user_id,
      last_read_at: now
    })
    |> Repo.insert(
      on_conflict: [set: [last_read_at: now, updated_at: now]],
      conflict_target: [:item_type, :item_id, :user_id]
    )
  end

  @doc """
  Returns a list of item_ids that have unread messages for a user,
  for a given item_type ("channel" or "dm").

  Compares the user's last_read_at vs. the latest message timestamp in each entity.

  ## Examples

      iex> list_unread_item_ids("channel", user_id)
      ["channel-id-1", "channel-id-3"]

  """
  def list_unread_item_ids(item_type, user_id) do
    # Get the message entity_type that corresponds to the item_type
    entity_type = item_type

    # Subquery: latest message per entity
    latest_messages =
      from(m in Message,
        where: m.entity_type == ^entity_type and is_nil(m.parent_id),
        group_by: m.entity_id,
        select: %{entity_id: m.entity_id, latest_at: max(m.inserted_at)}
      )

    # Join with read positions to find entities where latest message > last_read_at
    # Also include entities with no read position (never opened)
    from(lm in subquery(latest_messages),
      left_join: rp in ReadPosition,
      on:
        rp.item_type == ^item_type and
          rp.item_id == lm.entity_id and
          rp.user_id == ^user_id,
      where: is_nil(rp.id) or lm.latest_at > rp.last_read_at,
      select: lm.entity_id
    )
    |> Repo.all()
  end

  @doc """
  Gets all read positions for a user.

  ## Examples

      iex> get_read_positions(user_id)
      [%ReadPosition{}, ...]

  """
  def get_read_positions(user_id) do
    ReadPosition
    |> where([rp], rp.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Gets the read position for a specific item and user.

  Returns `nil` if no read position exists (user has never visited).
  """
  def get_read_position(item_type, item_id, user_id) do
    ReadPosition
    |> where([rp], rp.item_type == ^item_type and rp.item_id == ^item_id and rp.user_id == ^user_id)
    |> Repo.one()
  end
end
