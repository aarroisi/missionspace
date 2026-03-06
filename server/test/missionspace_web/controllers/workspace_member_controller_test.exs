defmodule MissionspaceWeb.WorkspaceMemberControllerTest do
  use MissionspaceWeb.ConnCase

  describe "index" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")

      member =
        insert(:user,
          workspace_id: workspace.id,
          role: "member",
          timezone: "Asia/Kolkata"
        )

      guest = insert(:user, workspace_id: workspace.id, role: "guest")

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, workspace: workspace, owner: owner, member: member, guest: guest}
    end

    test "lists all workspace members for owner", %{
      conn: conn,
      owner: owner,
      member: member,
      guest: guest
    } do
      response =
        conn
        |> get(~p"/api/workspace/members")
        |> json_response(200)

      user_ids = Enum.map(response["data"], & &1["id"])
      assert owner.id in user_ids
      assert member.id in user_ids
      assert guest.id in user_ids

      member_data = Enum.find(response["data"], &(&1["id"] == member.id))
      assert member_data["timezone"] == "Asia/Kolkata"
    end

    test "allows non-owners to view member list", %{conn: conn, member: member} do
      conn =
        conn
        |> put_session(:user_id, member.id)

      response =
        conn
        |> get(~p"/api/workspace/members")
        |> json_response(200)

      # Non-owners can view members
      assert is_list(response["data"])
    end
  end

  describe "show" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")

      member =
        insert(:user,
          workspace_id: workspace.id,
          role: "member",
          timezone: "Europe/Berlin"
        )

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, workspace: workspace, member: member}
    end

    test "shows member details including timezone", %{conn: conn, member: member} do
      response =
        conn
        |> get(~p"/api/workspace/members/#{member.id}")
        |> json_response(200)

      assert response["data"]["id"] == member.id
      assert response["data"]["timezone"] == "Europe/Berlin"
    end
  end

  describe "create" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, workspace: workspace, owner: owner}
    end

    test "creates a new member", %{conn: conn} do
      member_params = %{
        name: "New User",
        email: "newuser@example.com",
        password: "password123",
        role: "member"
      }

      response =
        conn
        |> post(~p"/api/workspace/members", member_params)
        |> json_response(201)

      assert response["data"]["name"] == "New User"
      assert response["data"]["email"] == "newuser@example.com"
      assert response["data"]["role"] == "member"
    end

    test "creates a new guest", %{conn: conn} do
      member_params = %{
        name: "Guest User",
        email: "guest@example.com",
        password: "password123",
        role: "guest"
      }

      response =
        conn
        |> post(~p"/api/workspace/members", member_params)
        |> json_response(201)

      assert response["data"]["role"] == "guest"
    end

    test "returns error for invalid data", %{conn: conn} do
      member_params = %{name: "", email: "invalid"}

      response =
        conn
        |> post(~p"/api/workspace/members", member_params)
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns 403 for non-owners", %{conn: conn, workspace: workspace} do
      existing_member = insert(:user, workspace_id: workspace.id, role: "member")

      conn =
        conn
        |> put_session(:user_id, existing_member.id)

      conn
      |> post(
        ~p"/api/workspace/members",
        %{name: "Test", email: "test@test.com", password: "pass123"}
      )
      |> json_response(403)
    end
  end

  describe "update" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      member = insert(:user, workspace_id: workspace.id, role: "member")

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, workspace: workspace, owner: owner, member: member}
    end

    test "updates member role", %{conn: conn, member: member} do
      response =
        conn
        |> put(~p"/api/workspace/members/#{member.id}", %{role: "guest"})
        |> json_response(200)

      assert response["data"]["role"] == "guest"
    end

    test "returns 404 for user from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      conn
      |> put(~p"/api/workspace/members/#{other_user.id}", %{role: "guest"})
      |> json_response(404)
    end

    test "returns 403 for non-owners", %{conn: conn, workspace: workspace, member: member} do
      conn =
        conn
        |> put_session(:user_id, member.id)

      conn
      |> put(~p"/api/workspace/members/#{member.id}", %{role: "guest"})
      |> json_response(403)
    end
  end

  describe "delete" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      member = insert(:user, workspace_id: workspace.id, role: "member")

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, owner.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, workspace: workspace, owner: owner, member: member}
    end

    test "soft-deletes a member", %{conn: conn, member: member} do
      conn
      |> delete(~p"/api/workspace/members/#{member.id}")
      |> response(204)

      # User record should still exist but be inactive
      {:ok, deleted_user} = Missionspace.Accounts.get_user(member.id)
      assert deleted_user.is_active == false
      assert deleted_user.deleted_at != nil
    end

    test "soft-deleted member no longer appears in member list", %{conn: conn, member: member} do
      # Delete the member
      conn
      |> delete(~p"/api/workspace/members/#{member.id}")
      |> response(204)

      # Fetch members list
      response =
        conn
        |> get(~p"/api/workspace/members")
        |> json_response(200)

      user_ids = Enum.map(response["data"], & &1["id"])
      refute member.id in user_ids
    end

    test "soft-deleted member email is freed for reuse", %{
      conn: conn,
      workspace: workspace,
      member: member
    } do
      original_email = member.email

      conn
      |> delete(~p"/api/workspace/members/#{member.id}")
      |> response(204)

      # Should be able to create a new user with the same email
      new_member_params = %{
        name: "New User",
        email: original_email,
        password: "password123",
        role: "member"
      }

      response =
        conn
        |> post(~p"/api/workspace/members", new_member_params)
        |> json_response(201)

      assert response["data"]["email"] == original_email
    end

    test "returns 404 for user from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      conn
      |> delete(~p"/api/workspace/members/#{other_user.id}")
      |> json_response(404)
    end

    test "returns 403 for non-owners", %{conn: conn, workspace: workspace, member: member} do
      conn =
        conn
        |> put_session(:user_id, member.id)

      conn
      |> delete(~p"/api/workspace/members/#{member.id}")
      |> json_response(403)
    end
  end
end
