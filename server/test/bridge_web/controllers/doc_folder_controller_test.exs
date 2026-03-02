defmodule BridgeWeb.DocFolderControllerTest do
  use BridgeWeb.ConnCase

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)
    project = insert(:project, workspace_id: workspace.id)
    insert(:project_member, project_id: project.id, user_id: user.id)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, workspace: workspace, user: user, project: project}
  end

  describe "index" do
    test "returns empty list when no folders", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/doc-folders")
        |> json_response(200)

      assert response["data"] == []
    end

    test "returns list of doc folders", %{conn: conn, workspace: workspace, user: user} do
      folder1 =
        insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id, prefix: "AA")

      folder2 =
        insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id, prefix: "BB")

      response =
        conn
        |> get(~p"/api/doc-folders")
        |> json_response(200)

      folder_ids = Enum.map(response["data"], & &1["id"])
      assert folder1.id in folder_ids
      assert folder2.id in folder_ids
    end

    test "does not return folders from other workspaces", %{
      conn: conn,
      workspace: workspace,
      user: user
    } do
      _our_folder =
        insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id, prefix: "OUR")

      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      other_folder =
        insert(:doc_folder,
          workspace_id: other_workspace.id,
          created_by_id: other_user.id,
          prefix: "OTH"
        )

      response =
        conn
        |> get(~p"/api/doc-folders")
        |> json_response(200)

      folder_ids = Enum.map(response["data"], & &1["id"])
      refute other_folder.id in folder_ids
    end
  end

  describe "create" do
    test "creates doc folder with valid attributes", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "My Docs", "prefix" => "MD"})
        |> json_response(201)

      assert response["data"]["name"] == "My Docs"
      assert response["data"]["prefix"] == "MD"
      assert response["data"]["id"]
      assert response["data"]["starred"] == false
    end

    test "returns errors with empty name", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "", "prefix" => "MD"})
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns errors with invalid prefix", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "Test", "prefix" => "a"})
        |> json_response(422)

      assert response["errors"]["prefix"]
    end

    test "sets workspace to current user's workspace", %{conn: conn, workspace: workspace} do
      response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "Test Folder", "prefix" => "TF"})
        |> json_response(201)

      folder = Bridge.Repo.get!(Bridge.Docs.DocFolder, response["data"]["id"])
      assert folder.workspace_id == workspace.id
    end

    test "sets created_by_id to current user", %{conn: conn, user: user} do
      response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "My Folder", "prefix" => "MF"})
        |> json_response(201)

      assert response["data"]["created_by_id"] == user.id
      assert response["data"]["created_by"]["id"] == user.id
    end

    test "rejects duplicate prefix within workspace (cross-type collision)", %{
      conn: conn,
      workspace: workspace,
      user: user
    } do
      # Create a board (list) first with prefix "DUP"
      {:ok, _list} =
        Bridge.Lists.create_list(%{
          "name" => "A Board",
          "prefix" => "DUP",
          "workspace_id" => workspace.id,
          "created_by_id" => user.id
        })

      # Attempt to create a doc folder with the same prefix should fail
      response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "A Doc Folder", "prefix" => "DUP"})
        |> json_response(422)

      # The namespace constraint error surfaces on workspace_id (the unique index's first field)
      assert response["errors"]["workspace_id"] || response["errors"]["prefix"]
    end
  end

  describe "show" do
    test "returns doc folder when it exists", %{
      conn: conn,
      workspace: workspace,
      user: user
    } do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: user.id,
          name: "Test Folder",
          prefix: "TF"
        )

      response =
        conn
        |> get(~p"/api/doc-folders/#{folder.id}")
        |> json_response(200)

      assert response["data"]["id"] == folder.id
      assert response["data"]["name"] == "Test Folder"
      assert response["data"]["prefix"] == "TF"
      assert response["data"]["starred"] == false
    end

    test "returns 404 for non-existent folder", %{conn: conn} do
      conn
      |> get(~p"/api/doc-folders/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 for folder from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      other_folder =
        insert(:doc_folder,
          workspace_id: other_workspace.id,
          created_by_id: other_user.id,
          prefix: "OTH"
        )

      conn
      |> get(~p"/api/doc-folders/#{other_folder.id}")
      |> json_response(404)
    end
  end

  describe "update" do
    test "updates name", %{conn: conn, workspace: workspace, user: user} do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: user.id,
          name: "Old Name",
          prefix: "ON"
        )

      response =
        conn
        |> put(~p"/api/doc-folders/#{folder.id}", %{"name" => "New Name"})
        |> json_response(200)

      assert response["data"]["name"] == "New Name"
      assert response["data"]["id"] == folder.id
    end

    test "cannot change prefix (prefix is immutable)", %{
      conn: conn,
      workspace: workspace,
      user: user
    } do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: user.id,
          name: "Folder",
          prefix: "IM"
        )

      response =
        conn
        |> put(~p"/api/doc-folders/#{folder.id}", %{
          "name" => "Updated Folder",
          "prefix" => "ZZ"
        })
        |> json_response(200)

      # Prefix should remain unchanged because update changeset does not cast :prefix
      assert response["data"]["prefix"] == "IM"
      assert response["data"]["name"] == "Updated Folder"
    end

    test "returns error with empty name", %{conn: conn, workspace: workspace, user: user} do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: user.id,
          prefix: "EN"
        )

      response =
        conn
        |> put(~p"/api/doc-folders/#{folder.id}", %{"name" => ""})
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns 404 for non-existent folder", %{conn: conn} do
      conn
      |> put(~p"/api/doc-folders/00000000-0000-0000-0000-000000000000", %{"name" => "New"})
      |> json_response(404)
    end

    test "returns 404 when updating folder from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      other_folder =
        insert(:doc_folder,
          workspace_id: other_workspace.id,
          created_by_id: other_user.id,
          prefix: "OTH"
        )

      conn
      |> put(~p"/api/doc-folders/#{other_folder.id}", %{"name" => "Hacked"})
      |> json_response(404)
    end
  end

  describe "delete" do
    test "deletes doc folder", %{conn: conn, workspace: workspace, user: user} do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: user.id,
          prefix: "DL"
        )

      conn
      |> delete(~p"/api/doc-folders/#{folder.id}")
      |> response(204)

      # Verify it no longer exists
      conn
      |> get(~p"/api/doc-folders/#{folder.id}")
      |> json_response(404)
    end

    test "deleted folder no longer appears in index", %{
      conn: conn,
      workspace: workspace,
      user: user
    } do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: user.id,
          prefix: "DI"
        )

      conn
      |> delete(~p"/api/doc-folders/#{folder.id}")
      |> response(204)

      response =
        conn
        |> get(~p"/api/doc-folders")
        |> json_response(200)

      folder_ids = Enum.map(response["data"], & &1["id"])
      refute folder.id in folder_ids
    end

    test "releases the prefix (can create new entity with same prefix after delete)", %{
      conn: conn
    } do
      # Create a doc folder via the API so the prefix is reserved in the namespace
      create_response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "Temp Folder", "prefix" => "TP"})
        |> json_response(201)

      folder_id = create_response["data"]["id"]

      # Delete the folder
      conn
      |> delete(~p"/api/doc-folders/#{folder_id}")
      |> response(204)

      # The prefix should now be available again - create a new folder with the same prefix
      reuse_response =
        conn
        |> post(~p"/api/doc-folders", %{"name" => "Reused Folder", "prefix" => "TP"})
        |> json_response(201)

      assert reuse_response["data"]["prefix"] == "TP"
      assert reuse_response["data"]["name"] == "Reused Folder"
    end

    test "returns 404 for non-existent folder", %{conn: conn} do
      conn
      |> delete(~p"/api/doc-folders/00000000-0000-0000-0000-000000000000")
      |> json_response(404)
    end

    test "returns 404 when deleting folder from another workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      other_folder =
        insert(:doc_folder,
          workspace_id: other_workspace.id,
          created_by_id: other_user.id,
          prefix: "OTH"
        )

      conn
      |> delete(~p"/api/doc-folders/#{other_folder.id}")
      |> json_response(404)
    end
  end

  describe "suggest_prefix" do
    test "returns a suggested prefix based on name", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/doc-folders/suggest-prefix?name=My Docs")
        |> json_response(200)

      assert is_binary(response["data"]["prefix"])
      assert String.length(response["data"]["prefix"]) >= 2
      assert String.length(response["data"]["prefix"]) <= 5
    end

    test "suggested prefix avoids collisions", %{conn: conn, workspace: workspace, user: user} do
      # Reserve the obvious prefix "MD" via creating a board
      {:ok, _list} =
        Bridge.Lists.create_list(%{
          "name" => "MD Board",
          "prefix" => "MD",
          "workspace_id" => workspace.id,
          "created_by_id" => user.id
        })

      response =
        conn
        |> get(~p"/api/doc-folders/suggest-prefix?name=My Documents")
        |> json_response(200)

      # The suggestion should not be "MD" since it is taken
      refute response["data"]["prefix"] == "MD"
      assert is_binary(response["data"]["prefix"])
    end
  end

  describe "check_prefix" do
    test "returns available=true for unused prefix", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/doc-folders/check-prefix?prefix=AB")
        |> json_response(200)

      assert response["data"]["available"] == true
    end

    test "returns available=false for used prefix", %{
      conn: conn,
      workspace: workspace,
      user: user
    } do
      # Reserve prefix via creating a board
      {:ok, _list} =
        Bridge.Lists.create_list(%{
          "name" => "Used Board",
          "prefix" => "UB",
          "workspace_id" => workspace.id,
          "created_by_id" => user.id
        })

      response =
        conn
        |> get(~p"/api/doc-folders/check-prefix?prefix=UB")
        |> json_response(200)

      assert response["data"]["available"] == false
    end
  end
end
