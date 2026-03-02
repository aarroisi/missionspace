defmodule BridgeWeb.SearchControllerTest do
  use BridgeWeb.ConnCase

  setup do
    workspace = insert(:workspace)
    owner = insert(:user, workspace_id: workspace.id, role: "owner")
    member = insert(:user, workspace_id: workspace.id, role: "member")

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
     member: member}
  end

  describe "index" do
    test "returns empty results for empty query", %{owner_conn: conn} do
      response =
        conn
        |> get(~p"/api/search")
        |> json_response(200)

      assert response["data"]["projects"] == []
      assert response["data"]["boards"] == []
      assert response["data"]["tasks"] == []
      assert response["data"]["docs"] == []
      assert response["data"]["channels"] == []
      assert response["data"]["members"] == []
    end

    test "returns empty results for blank query", %{owner_conn: conn} do
      response =
        conn
        |> get(~p"/api/search?q=")
        |> json_response(200)

      assert response["data"]["projects"] == []
    end

    test "searches projects by name", %{owner_conn: conn, workspace: workspace, owner: owner} do
      project =
        insert(:project,
          name: "Design System",
          workspace_id: workspace.id,
          created_by_id: owner.id
        )

      response =
        conn
        |> get(~p"/api/search?q=design")
        |> json_response(200)

      project_ids = Enum.map(response["data"]["projects"], & &1["id"])
      assert project.id in project_ids
    end

    test "searches boards by name and prefix", %{
      owner_conn: conn,
      workspace: workspace,
      owner: owner
    } do
      board =
        insert(:list,
          name: "Sprint Board",
          prefix: "SPR",
          workspace_id: workspace.id,
          created_by_id: owner.id
        )

      # Search by name
      response =
        conn
        |> get(~p"/api/search?q=sprint")
        |> json_response(200)

      board_ids = Enum.map(response["data"]["boards"], & &1["id"])
      assert board.id in board_ids

      # Search by prefix
      response =
        conn
        |> get(~p"/api/search?q=SPR")
        |> json_response(200)

      board_ids = Enum.map(response["data"]["boards"], & &1["id"])
      assert board.id in board_ids
    end

    test "searches tasks by title and key", %{
      owner_conn: conn,
      workspace: workspace,
      owner: owner
    } do
      board =
        insert(:list,
          name: "Dev Board",
          prefix: "DEV",
          workspace_id: workspace.id,
          created_by_id: owner.id
        )

      task =
        insert(:task,
          title: "Fix login bug",
          list_id: board.id,
          sequence_number: 42,
          created_by_id: owner.id
        )

      # Search by title
      response =
        conn
        |> get(~p"/api/search?q=login")
        |> json_response(200)

      task_ids = Enum.map(response["data"]["tasks"], & &1["id"])
      assert task.id in task_ids

      # Verify key is returned
      task_data = Enum.find(response["data"]["tasks"], &(&1["id"] == task.id))
      assert task_data["key"] == "DEV-42"

      # Search by key
      response =
        conn
        |> get(~p"/api/search?q=DEV-42")
        |> json_response(200)

      task_ids = Enum.map(response["data"]["tasks"], & &1["id"])
      assert task.id in task_ids
    end

    test "searches docs by title", %{owner_conn: conn, workspace: workspace, owner: owner} do
      folder =
        insert(:doc_folder,
          name: "Docs",
          prefix: "DOC",
          workspace_id: workspace.id,
          created_by_id: owner.id
        )

      doc =
        insert(:doc,
          title: "API Reference Guide",
          workspace_id: workspace.id,
          author_id: owner.id,
          doc_folder_id: folder.id
        )

      response =
        conn
        |> get(~p"/api/search?q=reference")
        |> json_response(200)

      doc_ids = Enum.map(response["data"]["docs"], & &1["id"])
      assert doc.id in doc_ids
    end

    test "searches channels by name", %{owner_conn: conn, workspace: workspace, owner: owner} do
      channel =
        insert(:channel,
          name: "general-chat",
          workspace_id: workspace.id,
          created_by_id: owner.id
        )

      response =
        conn
        |> get(~p"/api/search?q=general")
        |> json_response(200)

      channel_ids = Enum.map(response["data"]["channels"], & &1["id"])
      assert channel.id in channel_ids
    end

    test "searches members by name and email", %{owner_conn: conn, workspace: workspace} do
      user =
        insert(:user,
          name: "Alice Johnson",
          email: "alice@example.com",
          workspace_id: workspace.id,
          role: "member"
        )

      # Search by name
      response =
        conn
        |> get(~p"/api/search?q=alice")
        |> json_response(200)

      member_ids = Enum.map(response["data"]["members"], & &1["id"])
      assert user.id in member_ids

      # Search by email
      response =
        conn
        |> get(~p"/api/search?q=alice@example")
        |> json_response(200)

      member_ids = Enum.map(response["data"]["members"], & &1["id"])
      assert user.id in member_ids
    end

    test "does not return results from other workspaces", %{
      owner_conn: conn
    } do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id, role: "owner")

      insert(:channel,
        name: "secret-channel",
        workspace_id: other_workspace.id,
        created_by_id: other_user.id
      )

      insert(:project,
        name: "Secret Project",
        workspace_id: other_workspace.id,
        created_by_id: other_user.id
      )

      response =
        conn
        |> get(~p"/api/search?q=secret")
        |> json_response(200)

      assert response["data"]["channels"] == []
      assert response["data"]["projects"] == []
    end

    test "member cannot see private items they don't own", %{
      member_conn: conn,
      workspace: workspace,
      owner: owner
    } do
      # Owner creates a private board
      insert(:list,
        name: "Private Board",
        prefix: "PRV",
        workspace_id: workspace.id,
        created_by_id: owner.id,
        visibility: "private"
      )

      response =
        conn
        |> get(~p"/api/search?q=private")
        |> json_response(200)

      assert response["data"]["boards"] == []
    end

    test "member can see their own items", %{
      member_conn: conn,
      workspace: workspace,
      member: member
    } do
      board =
        insert(:list,
          name: "My Board",
          prefix: "MYB",
          workspace_id: workspace.id,
          created_by_id: member.id
        )

      response =
        conn
        |> get(~p"/api/search?q=my board")
        |> json_response(200)

      board_ids = Enum.map(response["data"]["boards"], & &1["id"])
      assert board.id in board_ids
    end
  end
end
