defmodule MissionspaceWeb.DirectMessageControllerTest do
  use MissionspaceWeb.ConnCase

  alias Missionspace.Chat

  setup do
    workspace = insert(:workspace)
    user1 = insert(:user, workspace_id: workspace.id, role: "member")
    user2 = insert(:user, workspace_id: workspace.id, role: "member")
    user3 = insert(:user, workspace_id: workspace.id, role: "member")

    conn1 =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user1.id)
      |> put_req_header("accept", "application/json")

    conn2 =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user2.id)
      |> put_req_header("accept", "application/json")

    conn3 =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user3.id)
      |> put_req_header("accept", "application/json")

    {:ok,
     conn1: conn1,
     conn2: conn2,
     conn3: conn3,
     workspace: workspace,
     user1: user1,
     user2: user2,
     user3: user3}
  end

  describe "create" do
    test "creates a new DM and returns user data", %{
      conn1: conn,
      user1: user1,
      user2: user2
    } do
      conn = post(conn, ~p"/api/direct_messages", %{"user2_id" => user2.id})

      assert %{"data" => dm} = json_response(conn, 201)
      assert dm["user1_id"] == user1.id
      assert dm["user2_id"] == user2.id
      assert dm["user1"]["name"] == user1.name
      assert dm["user2"]["name"] == user2.name
      assert dm["user1"]["email"] == user1.email
      assert dm["user2"]["email"] == user2.email
    end

    test "is idempotent — returns existing DM", %{
      conn1: conn,
      user2: user2
    } do
      conn1 = post(conn, ~p"/api/direct_messages", %{"user2_id" => user2.id})
      assert %{"data" => dm1} = json_response(conn1, 201)

      # Create again with same user
      conn2 =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, conn.assigns[:current_user] || dm1["user1_id"])
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/direct_messages", %{"user2_id" => user2.id})

      assert %{"data" => dm2} = json_response(conn2, 201)
      assert dm1["id"] == dm2["id"]
    end
  end

  describe "index" do
    test "lists DMs for current user with user data", %{
      conn1: conn,
      user1: user1,
      user2: user2,
      workspace: workspace
    } do
      insert(:direct_message,
        user1_id: user1.id,
        user2_id: user2.id,
        workspace_id: workspace.id
      )

      conn = get(conn, ~p"/api/direct_messages")
      assert %{"data" => [dm]} = json_response(conn, 200)
      assert dm["user1"]["name"] == user1.name
      assert dm["user2"]["name"] == user2.name
    end

    test "does not list DMs the user is not part of", %{
      conn3: conn,
      user1: user1,
      user2: user2,
      workspace: workspace
    } do
      insert(:direct_message,
        user1_id: user1.id,
        user2_id: user2.id,
        workspace_id: workspace.id
      )

      conn = get(conn, ~p"/api/direct_messages")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "show" do
    test "returns DM with user data", %{
      conn1: conn,
      user1: user1,
      user2: user2,
      workspace: workspace
    } do
      dm =
        insert(:direct_message,
          user1_id: user1.id,
          user2_id: user2.id,
          workspace_id: workspace.id
        )

      conn = get(conn, ~p"/api/direct_messages/#{dm.id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == dm.id
      assert data["user1"]["name"] == user1.name
      assert data["user2"]["name"] == user2.name
    end

    test "returns 403 when user is not part of DM", %{
      conn3: conn,
      user1: user1,
      user2: user2,
      workspace: workspace
    } do
      dm =
        insert(:direct_message,
          user1_id: user1.id,
          user2_id: user2.id,
          workspace_id: workspace.id
        )

      conn = get(conn, ~p"/api/direct_messages/#{dm.id}")
      assert json_response(conn, 403)
    end
  end

  describe "delete" do
    test "deletes a DM the user is part of", %{
      conn1: conn,
      user1: user1,
      user2: user2,
      workspace: workspace
    } do
      dm =
        insert(:direct_message,
          user1_id: user1.id,
          user2_id: user2.id,
          workspace_id: workspace.id
        )

      conn = delete(conn, ~p"/api/direct_messages/#{dm.id}")
      assert response(conn, 204)

      assert {:error, :not_found} == Chat.get_direct_message(dm.id, workspace.id)
    end
  end
end
