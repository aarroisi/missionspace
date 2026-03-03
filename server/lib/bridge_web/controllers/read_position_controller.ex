defmodule BridgeWeb.ReadPositionController do
  use BridgeWeb, :controller

  alias Bridge.Chat

  action_fallback(BridgeWeb.FallbackController)

  @doc """
  GET /api/read-positions/:item_type/:item_id
  Returns the user's last_read_at for a specific item (before marking as read).
  """
  def show(conn, %{"item_type" => item_type, "item_id" => item_id}) do
    current_user = conn.assigns.current_user
    read_position = Chat.get_read_position(item_type, item_id, current_user.id)

    json(conn, %{
      data: %{
        lastReadAt: if(read_position, do: read_position.last_read_at, else: nil)
      }
    })
  end

  @doc """
  POST /api/read-positions/:item_type/:item_id
  Marks an item as read for the current user. Upserts last_read_at to now.
  """
  def create(conn, %{"item_type" => item_type, "item_id" => item_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _read_position} <- Chat.update_read_position(item_type, item_id, current_user.id) do
      json(conn, %{data: %{status: "ok"}})
    end
  end

  @doc """
  GET /api/read-positions/unread
  Returns all unread channel and DM ids for the current user's sidebar.
  """
  def unread(conn, _params) do
    current_user = conn.assigns.current_user

    unread_channels = Chat.list_unread_item_ids("channel", current_user.id)
    unread_dms = Chat.list_unread_item_ids("dm", current_user.id)

    json(conn, %{
      data: %{
        channels: unread_channels,
        dms: unread_dms
      }
    })
  end
end
