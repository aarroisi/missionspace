defmodule MissionspaceWeb.MessageControllerTest do
  use MissionspaceWeb.ConnCase

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)
    project = insert(:project, workspace_id: workspace.id)
    channel = insert(:channel, workspace_id: workspace.id)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, workspace: workspace, user: user, project: project, channel: channel}
  end

  describe "index" do
    test "returns all messages for a specific entity", %{conn: conn, user: user, channel: channel} do
      message1 = insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)
      message2 = insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      response =
        conn
        |> get(~p"/api/messages?entity_type=channel&entity_id=#{channel.id}")
        |> json_response(200)

      message_ids = Enum.map(response["data"], & &1["id"])
      assert message1.id in message_ids
      assert message2.id in message_ids
    end

    test "does not return messages from other entities", %{
      conn: conn,
      user: user,
      workspace: workspace,
      channel: channel
    } do
      other_channel = insert(:channel, workspace_id: workspace.id)

      _message_in_channel =
        insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      other_message =
        insert(:message, entity_type: "channel", entity_id: other_channel.id, user_id: user.id)

      response =
        conn
        |> get(~p"/api/messages?entity_type=channel&entity_id=#{channel.id}")
        |> json_response(200)

      message_ids = Enum.map(response["data"], & &1["id"])
      refute other_message.id in message_ids
    end

    test "returns empty list when no messages exist", %{conn: conn, channel: channel} do
      response =
        conn
        |> get(~p"/api/messages?entity_type=channel&entity_id=#{channel.id}")
        |> json_response(200)

      assert response["data"] == []
    end

    test "returns paginated results with correct metadata", %{
      conn: conn,
      user: user,
      channel: channel
    } do
      # Create 5 messages
      for _ <- 1..5 do
        insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)
      end

      response =
        conn
        |> get(~p"/api/messages?entity_type=channel&entity_id=#{channel.id}&limit=2")
        |> json_response(200)

      assert length(response["data"]) == 2
      assert response["metadata"]["limit"] == 2
      assert is_binary(response["metadata"]["after"]) or is_nil(response["metadata"]["after"])
      assert is_nil(response["metadata"]["before"])
    end
  end

  describe "create" do
    test "creates message with valid attributes", %{conn: conn, user: user, channel: channel} do
      message_params = %{
        text: "Hello, world!",
        entity_type: "channel",
        entity_id: channel.id
      }

      response =
        conn
        |> post(~p"/api/messages", message_params)
        |> json_response(201)

      assert response["data"]["text"] == "Hello, world!"
      assert response["data"]["entity_type"] == "channel"
      assert response["data"]["entity_id"] == channel.id
      assert response["data"]["user_id"] == user.id
      assert response["data"]["id"]
    end

    test "creates message with parent (reply)", %{conn: conn, user: user, channel: channel} do
      parent_message =
        insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      message_params = %{
        text: "This is a reply",
        entity_type: "channel",
        entity_id: channel.id,
        parent_id: parent_message.id
      }

      response =
        conn
        |> post(~p"/api/messages", message_params)
        |> json_response(201)

      assert response["data"]["text"] == "This is a reply"
      assert response["data"]["parent_id"] == parent_message.id
    end

    test "creates message with quote", %{conn: conn, user: user, channel: channel} do
      quoted_message =
        insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      message_params = %{
        text: "Quoting this message",
        entity_type: "channel",
        entity_id: channel.id,
        quote_id: quoted_message.id
      }

      response =
        conn
        |> post(~p"/api/messages", message_params)
        |> json_response(201)

      assert response["data"]["text"] == "Quoting this message"
      assert response["data"]["quote_id"] == quoted_message.id
    end

    test "created message appears in index", %{conn: conn, channel: channel} do
      message_params = %{
        text: "Test message",
        entity_type: "channel",
        entity_id: channel.id
      }

      create_response =
        conn
        |> post(~p"/api/messages", message_params)
        |> json_response(201)

      message_id = create_response["data"]["id"]

      index_response =
        conn
        |> get(~p"/api/messages?entity_type=channel&entity_id=#{channel.id}")
        |> json_response(200)

      message_ids = Enum.map(index_response["data"], & &1["id"])
      assert message_id in message_ids
    end

    test "returns error with invalid attributes", %{conn: conn} do
      message_params = %{
        text: ""
      }

      response =
        conn
        |> post(~p"/api/messages", message_params)
        |> json_response(422)

      assert response["errors"]["text"] || response["errors"]["entity_type"] ||
               response["errors"]["entity_id"]
    end

    test "returns error with invalid entity_type", %{conn: conn, channel: channel} do
      message_params = %{
        text: "Hello",
        entity_type: "invalid_type",
        entity_id: channel.id
      }

      response =
        conn
        |> post(~p"/api/messages", message_params)
        |> json_response(422)

      assert response["errors"]["entity_type"]
    end

    test "sets user_id to current user", %{conn: conn, user: user, channel: channel} do
      message_params = %{
        text: "Test message",
        entity_type: "channel",
        entity_id: channel.id
      }

      response =
        conn
        |> post(~p"/api/messages", message_params)
        |> json_response(201)

      assert response["data"]["user_id"] == user.id
    end
  end

  describe "show" do
    test "returns message by id", %{conn: conn, user: user, channel: channel} do
      message =
        insert(:message,
          entity_type: "channel",
          entity_id: channel.id,
          user_id: user.id,
          text: "Hello"
        )

      response =
        conn
        |> get(~p"/api/messages/#{message.id}")
        |> json_response(200)

      assert response["data"]["id"] == message.id
      assert response["data"]["text"] == "Hello"
      assert response["data"]["entity_type"] == "channel"
      assert response["data"]["entity_id"] == channel.id
    end

    test "returns 404 for non-existent message", %{conn: conn} do
      conn
      |> get(~p"/api/messages/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end
  end

  describe "update" do
    test "updates message with valid attributes", %{conn: conn, user: user, channel: channel} do
      message =
        insert(:message,
          entity_type: "channel",
          entity_id: channel.id,
          user_id: user.id,
          text: "Old text"
        )

      update_params = %{
        text: "Updated text"
      }

      response =
        conn
        |> put(~p"/api/messages/#{message.id}", update_params)
        |> json_response(200)

      assert response["data"]["text"] == "Updated text"
    end

    test "updated message reflects changes in show", %{conn: conn, user: user, channel: channel} do
      message =
        insert(:message,
          entity_type: "channel",
          entity_id: channel.id,
          user_id: user.id,
          text: "Old text"
        )

      update_params = %{text: "Updated text"}

      conn
      |> put(~p"/api/messages/#{message.id}", update_params)
      |> json_response(200)

      show_response =
        conn
        |> get(~p"/api/messages/#{message.id}")
        |> json_response(200)

      assert show_response["data"]["text"] == "Updated text"
    end

    test "returns error with invalid attributes", %{conn: conn, user: user, channel: channel} do
      message =
        insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      update_params = %{
        text: ""
      }

      response =
        conn
        |> put(~p"/api/messages/#{message.id}", update_params)
        |> json_response(422)

      assert response["errors"]["text"]
    end

    test "returns error with invalid entity_type", %{conn: conn, user: user, channel: channel} do
      message =
        insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      update_params = %{
        entity_type: "invalid_type"
      }

      response =
        conn
        |> put(~p"/api/messages/#{message.id}", update_params)
        |> json_response(422)

      assert response["errors"]["entity_type"]
    end

    test "returns 404 for non-existent message", %{conn: conn} do
      update_params = %{text: "New text"}

      conn
      |> put(~p"/api/messages/00000000-0000-0000-0000-000000000000", update_params)
      |> json_response(404)
    end
  end

  describe "delete" do
    test "deletes message", %{conn: conn, user: user, channel: channel} do
      message = insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      conn
      |> delete(~p"/api/messages/#{message.id}")
      |> response(204)
    end

    test "deleted message no longer appears in index", %{conn: conn, user: user, channel: channel} do
      message = insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      conn
      |> delete(~p"/api/messages/#{message.id}")
      |> response(204)

      index_response =
        conn
        |> get(~p"/api/messages?entity_type=channel&entity_id=#{channel.id}")
        |> json_response(200)

      message_ids = Enum.map(index_response["data"], & &1["id"])
      refute message.id in message_ids
    end

    test "deleted message returns 404 on show", %{conn: conn, user: user, channel: channel} do
      message = insert(:message, entity_type: "channel", entity_id: channel.id, user_id: user.id)

      conn
      |> delete(~p"/api/messages/#{message.id}")
      |> response(204)

      conn
      |> get(~p"/api/messages/#{message.id}")
      |> json_response(404)
    end

    test "returns 404 for non-existent message", %{conn: conn} do
      conn
      |> delete(~p"/api/messages/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end
  end
end
