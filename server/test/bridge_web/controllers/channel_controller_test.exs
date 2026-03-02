defmodule BridgeWeb.ChannelControllerTest do
  use BridgeWeb.ConnCase

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)
    project = insert(:project, workspace_id: workspace.id)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, workspace: workspace, user: user, project: project}
  end

  describe "index" do
    test "returns all channels in workspace", %{
      conn: conn,
      workspace: workspace
    } do
      channel1 = insert(:channel, workspace_id: workspace.id)
      channel2 = insert(:channel, workspace_id: workspace.id)

      response =
        conn
        |> get(~p"/api/channels")
        |> json_response(200)

      channel_ids = Enum.map(response["data"], & &1["id"])
      assert channel1.id in channel_ids
      assert channel2.id in channel_ids
    end

    test "does not return channels from other workspaces", %{
      conn: conn,
      workspace: workspace
    } do
      other_workspace = insert(:workspace)
      _channel_in_workspace = insert(:channel, workspace_id: workspace.id)

      other_channel =
        insert(:channel, workspace_id: other_workspace.id)

      response =
        conn
        |> get(~p"/api/channels")
        |> json_response(200)

      channel_ids = Enum.map(response["data"], & &1["id"])
      refute other_channel.id in channel_ids
    end

    test "returns empty list when no channels exist", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/channels")
        |> json_response(200)

      assert response["data"] == []
    end

    test "returns paginated results with correct metadata", %{
      conn: conn,
      workspace: workspace
    } do
      # Create 5 channels
      for _ <- 1..5 do
        insert(:channel, workspace_id: workspace.id)
      end

      response =
        conn
        |> get(~p"/api/channels?limit=2")
        |> json_response(200)

      assert length(response["data"]) == 2
      assert response["metadata"]["limit"] == 2
      assert is_binary(response["metadata"]["after"]) or is_nil(response["metadata"]["after"])
      assert is_nil(response["metadata"]["before"])
    end
  end

  describe "create" do
    test "creates channel with valid attributes", %{conn: conn} do
      channel_params = %{
        name: "New Channel",
        starred: false
      }

      response =
        conn
        |> post(~p"/api/channels", channel_params)
        |> json_response(201)

      assert response["data"]["name"] == "New Channel"
      assert response["data"]["starred"] == false
      assert response["data"]["id"]
    end

    test "created channel appears in index", %{conn: conn} do
      channel_params = %{
        name: "Test Channel"
      }

      create_response =
        conn
        |> post(~p"/api/channels", channel_params)
        |> json_response(201)

      channel_id = create_response["data"]["id"]

      index_response =
        conn
        |> get(~p"/api/channels")
        |> json_response(200)

      channel_ids = Enum.map(index_response["data"], & &1["id"])
      assert channel_id in channel_ids
    end

    test "returns error with invalid attributes", %{conn: conn} do
      channel_params = %{
        name: ""
      }

      response =
        conn
        |> post(~p"/api/channels", channel_params)
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "sets workspace to current user's workspace", %{
      conn: conn,
      workspace: workspace
    } do
      other_workspace = insert(:workspace)

      channel_params = %{
        name: "Test Channel"
      }

      create_response =
        conn
        |> post(~p"/api/channels", channel_params)
        |> json_response(201)

      channel_id = create_response["data"]["id"]

      # Verify the channel appears in current workspace's list
      index_response =
        conn
        |> get(~p"/api/channels")
        |> json_response(200)

      channel_ids = Enum.map(index_response["data"], & &1["id"])
      assert channel_id in channel_ids

      # Verify it's actually stored with the correct workspace_id
      channel = Bridge.Repo.get!(Bridge.Chat.Channel, channel_id)
      assert channel.workspace_id == workspace.id
      refute channel.workspace_id == other_workspace.id
    end
  end

  describe "show" do
    test "returns channel by id", %{conn: conn, workspace: workspace} do
      channel = insert(:channel, workspace_id: workspace.id)

      response =
        conn
        |> get(~p"/api/channels/#{channel.id}")
        |> json_response(200)

      assert response["data"]["id"] == channel.id
      assert response["data"]["name"] == channel.name
      assert response["data"]["starred"] == channel.starred
    end

    test "returns 404 for non-existent channel", %{conn: conn} do
      conn
      |> get(~p"/api/channels/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 for channel from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)

      other_channel =
        insert(:channel, workspace_id: other_workspace.id)

      conn
      |> get(~p"/api/channels/#{other_channel.id}")
      |> json_response(404)
    end
  end

  describe "update" do
    test "updates channel with valid attributes", %{
      conn: conn,
      workspace: workspace
    } do
      channel =
        insert(:channel,
          workspace_id: workspace.id,
          name: "Old Name"
        )

      update_params = %{
        name: "New Name"
      }

      response =
        conn
        |> put(~p"/api/channels/#{channel.id}", update_params)
        |> json_response(200)

      assert response["data"]["name"] == "New Name"
    end

    test "updated channel reflects changes in show", %{
      conn: conn,
      workspace: workspace
    } do
      channel =
        insert(:channel, workspace_id: workspace.id, name: "Old Name")

      update_params = %{name: "Updated Name"}

      conn
      |> put(~p"/api/channels/#{channel.id}", update_params)
      |> json_response(200)

      show_response =
        conn
        |> get(~p"/api/channels/#{channel.id}")
        |> json_response(200)

      assert show_response["data"]["name"] == "Updated Name"
    end

    test "returns error with invalid attributes", %{
      conn: conn,
      workspace: workspace
    } do
      channel = insert(:channel, workspace_id: workspace.id)

      update_params = %{
        name: ""
      }

      response =
        conn
        |> put(~p"/api/channels/#{channel.id}", update_params)
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns 404 for non-existent channel", %{conn: conn} do
      update_params = %{name: "New Name"}

      conn
      |> put(~p"/api/channels/00000000-0000-0000-0000-000000000000", update_params)
      |> json_response(404)
    end

    test "returns 404 when updating channel from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)

      other_channel =
        insert(:channel, workspace_id: other_workspace.id)

      update_params = %{name: "Hacked Name"}

      conn
      |> put(~p"/api/channels/#{other_channel.id}", update_params)
      |> json_response(404)
    end
  end

  describe "delete" do
    test "deletes channel", %{conn: conn, workspace: workspace} do
      channel = insert(:channel, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/channels/#{channel.id}")
      |> response(204)
    end

    test "deleted channel no longer appears in index", %{
      conn: conn,
      workspace: workspace
    } do
      channel = insert(:channel, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/channels/#{channel.id}")
      |> response(204)

      index_response =
        conn
        |> get(~p"/api/channels")
        |> json_response(200)

      channel_ids = Enum.map(index_response["data"], & &1["id"])
      refute channel.id in channel_ids
    end

    test "deleted channel returns 404 on show", %{
      conn: conn,
      workspace: workspace
    } do
      channel = insert(:channel, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/channels/#{channel.id}")
      |> response(204)

      conn
      |> get(~p"/api/channels/#{channel.id}")
      |> json_response(404)
    end

    test "returns 404 for non-existent channel", %{conn: conn} do
      conn
      |> delete(~p"/api/channels/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 when deleting channel from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)

      other_channel =
        insert(:channel, workspace_id: other_workspace.id)

      conn
      |> delete(~p"/api/channels/#{other_channel.id}")
      |> json_response(404)
    end
  end
end
