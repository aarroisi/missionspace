defmodule BridgeWeb.ListControllerTest do
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
    test "returns all lists in workspace", %{conn: conn, workspace: workspace} do
      list1 = insert(:list, workspace_id: workspace.id)
      list2 = insert(:list, workspace_id: workspace.id)

      response =
        conn
        |> get(~p"/api/boards")
        |> json_response(200)

      list_ids = Enum.map(response["data"], & &1["id"])
      assert list1.id in list_ids
      assert list2.id in list_ids
    end

    test "does not return lists from other workspaces", %{
      conn: conn,
      workspace: workspace
    } do
      other_workspace = insert(:workspace)
      _list_in_workspace = insert(:list, workspace_id: workspace.id)
      other_list = insert(:list, workspace_id: other_workspace.id)

      response =
        conn
        |> get(~p"/api/boards")
        |> json_response(200)

      list_ids = Enum.map(response["data"], & &1["id"])
      refute other_list.id in list_ids
    end

    test "returns empty list when no lists exist", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/boards")
        |> json_response(200)

      assert response["data"] == []
    end

    test "returns paginated results with correct metadata", %{
      conn: conn,
      workspace: workspace
    } do
      # Create 5 lists
      for _ <- 1..5 do
        insert(:list, workspace_id: workspace.id)
      end

      response =
        conn
        |> get(~p"/api/boards?limit=2")
        |> json_response(200)

      assert length(response["data"]) == 2
      assert response["metadata"]["limit"] == 2
      assert is_binary(response["metadata"]["after"]) or is_nil(response["metadata"]["after"])
      assert is_nil(response["metadata"]["before"])
    end
  end

  describe "create" do
    test "creates list with valid attributes using flat params", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/boards", %{name: "New List", prefix: "NL", starred: false})
        |> json_response(201)

      assert response["data"]["name"] == "New List"
      assert response["data"]["prefix"] == "NL"
      assert response["data"]["starred"] == false
      assert response["data"]["id"]
    end

    test "created list appears in index", %{conn: conn} do
      create_response =
        conn
        |> post(~p"/api/boards", %{name: "Test List", prefix: "TL"})
        |> json_response(201)

      list_id = create_response["data"]["id"]

      index_response =
        conn
        |> get(~p"/api/boards")
        |> json_response(200)

      list_ids = Enum.map(index_response["data"], & &1["id"])
      assert list_id in list_ids
    end

    test "returns error with invalid attributes", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/boards", %{name: "", prefix: "NL"})
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns error with invalid prefix format", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/boards", %{name: "Test", prefix: "a"})
        |> json_response(422)

      assert response["errors"]["prefix"]
    end

    test "returns error with duplicate prefix in same workspace", %{
      conn: conn,
      workspace: workspace
    } do
      insert(:list, workspace_id: workspace.id, prefix: "DUP")

      response =
        conn
        |> post(~p"/api/boards", %{name: "Another", prefix: "DUP"})
        |> json_response(422)

      assert response["errors"]["prefix"]
    end

    test "sets workspace to current user's workspace", %{
      conn: conn,
      workspace: workspace
    } do
      other_workspace = insert(:workspace)

      create_response =
        conn
        |> post(~p"/api/boards", %{name: "Test List", prefix: "TL"})
        |> json_response(201)

      list_id = create_response["data"]["id"]

      # Verify the list appears in current workspace's list
      index_response =
        conn
        |> get(~p"/api/boards")
        |> json_response(200)

      list_ids = Enum.map(index_response["data"], & &1["id"])
      assert list_id in list_ids

      # Verify it's actually stored with the correct workspace_id
      list = Bridge.Repo.get!(Bridge.Lists.List, list_id)
      assert list.workspace_id == workspace.id
      refute list.workspace_id == other_workspace.id
    end

    test "sets created_by_id to current user", %{conn: conn, user: user} do
      response =
        conn
        |> post(~p"/api/boards", %{name: "My List", prefix: "ML"})
        |> json_response(201)

      list = Bridge.Repo.get!(Bridge.Lists.List, response["data"]["id"])
      assert list.created_by_id == user.id
    end
  end

  describe "show" do
    test "returns list by id", %{conn: conn, workspace: workspace} do
      list = insert(:list, workspace_id: workspace.id)

      response =
        conn
        |> get(~p"/api/boards/#{list.id}")
        |> json_response(200)

      assert response["data"]["id"] == list.id
      assert response["data"]["name"] == list.name
      assert response["data"]["starred"] == list.starred
    end

    test "returns 404 for non-existent list", %{conn: conn} do
      conn
      |> get(~p"/api/boards/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 for list from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)

      conn
      |> get(~p"/api/boards/#{other_list.id}")
      |> json_response(404)
    end
  end

  describe "update" do
    test "updates list with valid attributes using flat params", %{
      conn: conn,
      workspace: workspace
    } do
      list =
        insert(:list,
          workspace_id: workspace.id,
          name: "Old Name"
        )

      response =
        conn
        |> put(~p"/api/boards/#{list.id}", %{name: "New Name"})
        |> json_response(200)

      assert response["data"]["name"] == "New Name"
    end

    test "updated list reflects changes in show", %{
      conn: conn,
      workspace: workspace
    } do
      list = insert(:list, workspace_id: workspace.id, name: "Old Name")

      conn
      |> put(~p"/api/boards/#{list.id}", %{name: "Updated Name"})
      |> json_response(200)

      show_response =
        conn
        |> get(~p"/api/boards/#{list.id}")
        |> json_response(200)

      assert show_response["data"]["name"] == "Updated Name"
    end

    test "returns error with invalid attributes", %{
      conn: conn,
      workspace: workspace
    } do
      list = insert(:list, workspace_id: workspace.id)

      response =
        conn
        |> put(~p"/api/boards/#{list.id}", %{name: ""})
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns 404 for non-existent list", %{conn: conn} do
      conn
      |> put(~p"/api/boards/00000000-0000-0000-0000-000000000000", %{name: "New Name"})
      |> json_response(404)
    end

    test "returns 404 when updating list from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)

      conn
      |> put(~p"/api/boards/#{other_list.id}", %{name: "Hacked Name"})
      |> json_response(404)
    end
  end

  describe "delete" do
    test "deletes list", %{conn: conn, workspace: workspace} do
      list = insert(:list, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/boards/#{list.id}")
      |> response(204)
    end

    test "deleted list no longer appears in index", %{
      conn: conn,
      workspace: workspace
    } do
      list = insert(:list, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/boards/#{list.id}")
      |> response(204)

      index_response =
        conn
        |> get(~p"/api/boards")
        |> json_response(200)

      list_ids = Enum.map(index_response["data"], & &1["id"])
      refute list.id in list_ids
    end

    test "deleted list returns 404 on show", %{conn: conn, workspace: workspace} do
      list = insert(:list, workspace_id: workspace.id)

      conn
      |> delete(~p"/api/boards/#{list.id}")
      |> response(204)

      conn
      |> get(~p"/api/boards/#{list.id}")
      |> json_response(404)
    end

    test "returns 404 for non-existent list", %{conn: conn} do
      conn
      |> delete(~p"/api/boards/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 when deleting list from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_list = insert(:list, workspace_id: other_workspace.id)

      conn
      |> delete(~p"/api/boards/#{other_list.id}")
      |> json_response(404)
    end
  end
end
