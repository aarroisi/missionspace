defmodule BridgeWeb.ItemMemberControllerTest do
  use BridgeWeb.ConnCase

  alias Bridge.Projects

  setup do
    workspace = insert(:workspace)
    owner = insert(:user, workspace_id: workspace.id, role: "owner")
    member = insert(:user, workspace_id: workspace.id, role: "member")
    guest = insert(:user, workspace_id: workspace.id, role: "guest")
    target_user = insert(:user, workspace_id: workspace.id, role: "member")

    channel =
      insert(:channel,
        workspace_id: workspace.id,
        created_by_id: owner.id,
        visibility: "shared"
      )

    owner_conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, owner.id)
      |> put_req_header("accept", "application/json")

    member_conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, member.id)
      |> put_req_header("accept", "application/json")

    {:ok,
     owner_conn: owner_conn,
     member_conn: member_conn,
     workspace: workspace,
     owner: owner,
     member: member,
     guest: guest,
     target_user: target_user,
     channel: channel}
  end

  describe "index" do
    test "lists item members", %{owner_conn: conn, channel: channel, target_user: target_user, workspace: workspace} do
      insert(:item_member,
        item_type: "channel",
        item_id: channel.id,
        user_id: target_user.id,
        workspace_id: workspace.id
      )

      conn = get(conn, ~p"/api/item-members/channel/#{channel.id}")
      assert %{"data" => [member]} = json_response(conn, 200)
      assert member["user_id"] == target_user.id
      assert member["user"]["name"] == target_user.name
    end
  end

  describe "create" do
    test "owner can add item members", %{owner_conn: conn, channel: channel, target_user: target_user} do
      conn =
        post(conn, ~p"/api/item-members/channel/#{channel.id}", %{
          "user_id" => target_user.id
        })

      assert %{"data" => member} = json_response(conn, 201)
      assert member["user_id"] == target_user.id
      assert member["item_type"] == "channel"
      assert member["item_id"] == channel.id
    end

    test "member cannot add item members on others' items", %{
      member_conn: conn,
      channel: channel,
      target_user: target_user
    } do
      conn =
        post(conn, ~p"/api/item-members/channel/#{channel.id}", %{
          "user_id" => target_user.id
        })

      assert json_response(conn, 403)
    end

    test "member can add item members on own shared items", %{
      member: member,
      workspace: workspace,
      target_user: target_user
    } do
      own_channel =
        insert(:channel,
          workspace_id: workspace.id,
          created_by_id: member.id,
          visibility: "shared"
        )

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, member.id)
        |> put_req_header("accept", "application/json")

      conn =
        post(conn, ~p"/api/item-members/channel/#{own_channel.id}", %{
          "user_id" => target_user.id
        })

      assert %{"data" => _member} = json_response(conn, 201)
    end

    test "prevents adding guest who already has a membership", %{
      owner_conn: conn,
      channel: channel,
      guest: guest,
      workspace: workspace
    } do
      # Give guest an existing project membership
      project = insert(:project, workspace_id: workspace.id)
      insert(:project_member, user_id: guest.id, project_id: project.id)

      conn =
        post(conn, ~p"/api/item-members/channel/#{channel.id}", %{
          "user_id" => guest.id
        })

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 404 for invalid item type", %{owner_conn: conn, target_user: target_user} do
      conn =
        post(conn, ~p"/api/item-members/invalid/#{UUIDv7.generate()}", %{
          "user_id" => target_user.id
        })

      assert json_response(conn, 404)
    end
  end

  describe "project items" do
    test "rejects adding members to items that belong to a project", %{
      owner_conn: conn,
      channel: channel,
      target_user: target_user,
      workspace: workspace
    } do
      project = insert(:project, workspace_id: workspace.id)
      {:ok, _} = Projects.add_item(project.id, "channel", channel.id)

      conn =
        post(conn, ~p"/api/item-members/channel/#{channel.id}", %{
          "user_id" => target_user.id
        })

      assert %{"errors" => %{"detail" => msg}} = json_response(conn, 422)
      assert msg =~ "belong to a project"
    end

    test "rejects listing members for items that belong to a project", %{
      owner_conn: conn,
      channel: channel,
      workspace: workspace
    } do
      project = insert(:project, workspace_id: workspace.id)
      {:ok, _} = Projects.add_item(project.id, "channel", channel.id)

      conn = get(conn, ~p"/api/item-members/channel/#{channel.id}")

      assert %{"errors" => %{"detail" => msg}} = json_response(conn, 422)
      assert msg =~ "belong to a project"
    end
  end

  describe "delete" do
    test "owner can remove item members", %{
      owner_conn: conn,
      channel: channel,
      target_user: target_user,
      workspace: workspace
    } do
      insert(:item_member,
        item_type: "channel",
        item_id: channel.id,
        user_id: target_user.id,
        workspace_id: workspace.id
      )

      conn = delete(conn, ~p"/api/item-members/channel/#{channel.id}/#{target_user.id}")
      assert response(conn, 204)

      refute Projects.is_item_member?("channel", channel.id, target_user.id)
    end

    test "returns 404 when removing non-existent member", %{
      owner_conn: conn,
      channel: channel,
      target_user: target_user
    } do
      conn = delete(conn, ~p"/api/item-members/channel/#{channel.id}/#{target_user.id}")
      assert json_response(conn, 404)
    end
  end
end
