defmodule MissionspaceWeb.ChatChannel do
  use MissionspaceWeb, :channel

  alias Missionspace.Chat
  alias Missionspace.Accounts
  alias Missionspace.Repo
  alias MissionspaceWeb.Presence

  @impl true
  def join("channel:" <> channel_id, _payload, socket) do
    # Verify that the channel exists and user has access
    workspace_id = socket.assigns.workspace_id

    case Chat.get_channel(channel_id, workspace_id) do
      {:ok, _channel} ->
        socket =
          socket
          |> assign(:channel_id, channel_id)
          |> assign(:room_type, "channel")

        send(self(), :after_join)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "channel not found"}}
    end
  end

  @impl true
  def join("dm:" <> dm_id, _payload, socket) do
    # Verify that the direct message conversation exists and user has access
    workspace_id = socket.assigns.workspace_id

    case Chat.get_direct_message(dm_id, workspace_id) do
      {:ok, dm} ->
        # Verify user is part of this DM
        user_id = socket.assigns.user_id

        if dm.user1_id == user_id or dm.user2_id == user_id do
          socket =
            socket
            |> assign(:dm_id, dm_id)
            |> assign(:room_type, "dm")

          send(self(), :after_join)
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end

      {:error, :not_found} ->
        {:error, %{reason: "direct message not found"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    # Get user information
    case Accounts.get_user(user_id) do
      {:ok, user} ->
        # Track presence for this user in the channel/DM
        topic = get_topic(socket)

        {:ok, _} =
          Presence.track(socket, user_id, %{
            user_id: user.id,
            name: user.name,
            avatar: user.avatar,
            online_at: System.system_time(:second)
          })

        # Push presence state to the client
        push(socket, "presence_state", Presence.list(topic))
        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_in("new_message", %{"text" => text} = payload, socket) do
    user_id = socket.assigns.user_id
    room_type = socket.assigns.room_type

    message_params =
      case room_type do
        "channel" ->
          channel_id = socket.assigns.channel_id

          %{
            text: text,
            entity_type: "channel",
            entity_id: channel_id,
            user_id: user_id
          }

        "dm" ->
          dm_id = socket.assigns.dm_id

          %{
            text: text,
            entity_type: "dm",
            entity_id: dm_id,
            user_id: user_id
          }
      end

    # Add optional parent_id for threading
    message_params =
      if Map.has_key?(payload, "parent_id") do
        Map.put(message_params, :parent_id, payload["parent_id"])
      else
        message_params
      end

    # Add optional quote_id for quoting
    message_params =
      if Map.has_key?(payload, "quote_id") do
        Map.put(message_params, :quote_id, payload["quote_id"])
      else
        message_params
      end

    case Chat.create_message(message_params) do
      {:ok, message} ->
        # Preload associations for broadcasting
        message = Repo.preload(message, [:user, :parent, :quote])

        # Broadcast the new message to all subscribers
        broadcast!(socket, "new_message", %{
          message: message
        })

        {:reply, {:ok, %{message: message}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    case Chat.get_message(message_id) do
      {:ok, message} ->
        # Verify the user owns this message
        if message.user_id == socket.assigns.user_id do
          case Chat.delete_message(message) do
            {:ok, _deleted_message} ->
              # Broadcast the deletion to all subscribers
              broadcast!(socket, "message_deleted", %{
                message_id: message_id
              })

              {:reply, :ok, socket}

            {:error, changeset} ->
              {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
          end
        else
          {:reply, {:error, %{reason: "unauthorized"}}, socket}
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "message not found"}}, socket}
    end
  end

  @impl true
  def handle_in("update_message", %{"message_id" => message_id, "text" => text}, socket) do
    case Chat.get_message(message_id) do
      {:ok, message} ->
        # Verify the user owns this message
        if message.user_id == socket.assigns.user_id do
          case Chat.update_message(message, %{text: text}) do
            {:ok, updated_message} ->
              # Preload associations for broadcasting
              updated_message = Repo.preload(updated_message, [:user, :parent, :quote])

              # Broadcast the update to all subscribers
              broadcast!(socket, "message_updated", %{
                message: updated_message
              })

              {:reply, {:ok, %{message: updated_message}}, socket}

            {:error, changeset} ->
              {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
          end
        else
          {:reply, {:error, %{reason: "unauthorized"}}, socket}
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "message not found"}}, socket}
    end
  end

  @impl true
  def handle_in("typing_start", _payload, socket) do
    user_id = socket.assigns.user_id

    # Broadcast typing indicator to other subscribers (not to self)
    broadcast_from!(socket, "user_typing", %{
      user_id: user_id,
      typing: true
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("typing_stop", _payload, socket) do
    user_id = socket.assigns.user_id

    # Broadcast typing stop to other subscribers (not to self)
    broadcast_from!(socket, "user_typing", %{
      user_id: user_id,
      typing: false
    })

    {:noreply, socket}
  end

  # Helper function to get the current topic
  defp get_topic(socket) do
    case socket.assigns.room_type do
      "channel" -> "channel:#{socket.assigns.channel_id}"
      "dm" -> "dm:#{socket.assigns.dm_id}"
    end
  end

  # Helper function to format changeset errors
  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
