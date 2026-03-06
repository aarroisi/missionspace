defmodule MissionspaceWeb.MessageController do
  use MissionspaceWeb, :controller

  alias Missionspace.Chat
  alias Missionspace.Mentions
  alias Missionspace.Authorization.Policy
  alias Missionspace.Authorization.Scopes
  alias MissionspaceWeb.MessageJSON
  import Plug.Conn

  action_fallback(MissionspaceWeb.FallbackController)

  plug(:load_resource when action in [:show, :update, :delete])
  plug(:authorize, :view_message when action in [:show])
  plug(:authorize, :create_message when action in [:create])
  plug(:authorize, :update_message when action in [:update])
  plug(:authorize, :delete_message when action in [:delete])

  defp load_resource(conn, _opts) do
    case Chat.get_message(conn.params["id"]) do
      {:ok, message} ->
        assign(conn, :message, message)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  defp authorize(conn, permission) do
    user = conn.assigns.current_user

    scope_allowed = Scopes.has_scope_for_action?(user, permission)

    allowed =
      case permission do
        :view_message ->
          # Anyone can view messages (entity access is handled at entity level)
          true

        :create_message ->
          # Check if user can comment on the entity
          # Support both camelCase (frontend) and snake_case (tests)
          message_params = conn.params["message"] || %{}
          entity_type = message_params["entityType"] || message_params["entity_type"]
          entity_id = message_params["entityId"] || message_params["entity_id"]

          cond do
            # If entity_type or entity_id is missing, let validation handle it
            is_nil(entity_type) or entity_type == "" or is_nil(entity_id) or entity_id == "" ->
              true

            # If entity_type is not a valid type, let validation handle it
            entity_type not in ["task", "doc", "channel", "dm"] ->
              true

            # Otherwise, check entity access
            true ->
              entity = get_entity(entity_type, entity_id, conn)
              entity != nil and Policy.can?(user, :comment, entity)
          end

        :update_message ->
          # Only message author can update
          conn.assigns.message.user_id == user.id

        :delete_message ->
          # Only message author can delete (or owner via Policy)
          conn.assigns.message.user_id == user.id or user.role == "owner"
      end

    if scope_allowed and allowed do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Forbidden"})
      |> halt()
    end
  end

  defp get_entity("task", id, _conn) when is_binary(id) do
    case Missionspace.Lists.get_task(id) do
      {:ok, task} -> task
      _ -> nil
    end
  end

  defp get_entity("doc", id, conn) when is_binary(id) do
    case Missionspace.Docs.get_doc(id, conn.assigns.workspace_id) do
      {:ok, doc} -> doc
      _ -> nil
    end
  end

  defp get_entity("channel", id, conn) when is_binary(id) do
    case Missionspace.Chat.get_channel(id, conn.assigns.workspace_id) do
      {:ok, channel} -> channel
      _ -> nil
    end
  end

  defp get_entity("dm", _id, _conn), do: %{project_id: :dm}
  defp get_entity(_, _, _), do: nil

  def index(conn, params) do
    opts = MissionspaceWeb.PaginationHelpers.build_pagination_opts(params)

    page =
      case {params["entity_type"], params["entity_id"]} do
        {entity_type, entity_id} when is_binary(entity_type) and is_binary(entity_id) ->
          Chat.list_messages_by_entity(entity_type, entity_id, opts)

        _ ->
          Chat.list_messages(opts)
      end

    render(conn, :index, page: page)
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id

    # Support both camelCase (frontend) and snake_case (tests) params
    attrs = %{
      "text" => params["text"],
      "entity_type" => params["entityType"] || params["entity_type"],
      "entity_id" => params["entityId"] || params["entity_id"],
      "parent_id" => params["parentId"] || params["parent_id"],
      "quote_id" => params["quoteId"] || params["quote_id"],
      "user_id" => current_user.id
    }

    with {:ok, message} <- Chat.create_message(attrs) do
      message = preload_message(message)

      broadcast_room_message(message, "new_message", %{message: MessageJSON.data(message)})

      # Create notifications for subscribers and mentioned users (async, don't block response)
      Task.start(fn ->
        Mentions.notify_for_new_message(message, current_user.id, workspace_id)
      end)

      conn
      |> put_status(:created)
      |> render(:show, message: message)
    end
  end

  def show(conn, _params) do
    render(conn, :show, message: conn.assigns.message)
  end

  def update(conn, params) do
    with {:ok, message} <- Chat.update_message(conn.assigns.message, params) do
      message = preload_message(message)

      broadcast_room_message(message, "message_updated", %{message: MessageJSON.data(message)})

      render(conn, :show, message: message)
    end
  end

  def delete(conn, _params) do
    message = conn.assigns.message

    with {:ok, _message} <- Chat.delete_message(message) do
      broadcast_room_message(message, "message_deleted", %{message_id: message.id})

      send_resp(conn, :no_content, "")
    end
  end

  defp preload_message(message) do
    Missionspace.Repo.preload(message, [:user, :parent, quote: [:user]])
  end

  defp broadcast_room_message(%{entity_type: entity_type, entity_id: entity_id}, event, payload) do
    case room_topic(entity_type, entity_id) do
      nil -> :ok
      topic -> MissionspaceWeb.Endpoint.broadcast(topic, event, payload)
    end
  end

  defp room_topic("channel", entity_id), do: "channel:#{entity_id}"
  defp room_topic("dm", entity_id), do: "dm:#{entity_id}"
  defp room_topic(_, _), do: nil
end
