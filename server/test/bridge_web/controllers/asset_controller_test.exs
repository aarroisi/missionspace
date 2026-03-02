defmodule BridgeWeb.AssetControllerTest do
  use BridgeWeb.ConnCase

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id)
    doc_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id)
    doc = insert(:doc, workspace_id: workspace.id, author_id: user.id, doc_folder_id: doc_folder.id)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, workspace: workspace, user: user, doc: doc}
  end

  describe "request_upload" do
    test "returns presigned URL and asset ID for valid request", %{conn: conn, doc: doc} do
      params = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        asset_type: "file",
        attachable_type: "doc",
        attachable_id: doc.id
      }

      response =
        conn
        |> post(~p"/api/assets/request-upload", params)
        |> json_response(201)

      assert response["data"]["id"]
      assert response["data"]["upload_url"]
      assert response["data"]["storage_key"]
    end

    test "rejects when attachable_type is missing", %{conn: conn, doc: doc} do
      params = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        asset_type: "file",
        attachable_id: doc.id
      }

      response =
        conn
        |> post(~p"/api/assets/request-upload", params)
        |> json_response(422)

      assert response["error"] == "attachable_type is required"
    end

    test "rejects when attachable_id is missing", %{conn: conn} do
      params = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        asset_type: "file",
        attachable_type: "doc"
      }

      response =
        conn
        |> post(~p"/api/assets/request-upload", params)
        |> json_response(422)

      assert response["error"] == "attachable_id is required"
    end

    test "rejects when attachable item not in workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)
      other_doc_folder = insert(:doc_folder, workspace_id: other_workspace.id, created_by_id: other_user.id)
      other_doc = insert(:doc, workspace_id: other_workspace.id, author_id: other_user.id, doc_folder_id: other_doc_folder.id)

      params = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        asset_type: "file",
        attachable_type: "doc",
        attachable_id: other_doc.id
      }

      response =
        conn
        |> post(~p"/api/assets/request-upload", params)
        |> json_response(422)

      assert response["error"] == "Attachable item not found in this workspace"
    end

    test "rejects file exceeding size limit", %{conn: conn, user: user} do
      params = %{
        filename: "large.png",
        content_type: "image/png",
        size_bytes: 10 * 1024 * 1024,
        asset_type: "avatar",
        attachable_type: "user",
        attachable_id: user.id
      }

      response =
        conn
        |> post(~p"/api/assets/request-upload", params)
        |> json_response(422)

      assert response["error"] == "File too large"
    end

    test "rejects when storage quota exceeded", %{conn: _conn} do
      # Create workspace with storage almost full
      workspace = insert(:workspace, storage_used_bytes: 5_368_709_120 - 500)
      user = insert(:user, workspace_id: workspace.id)
      doc_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id)
      doc = insert(:doc, workspace_id: workspace.id, author_id: user.id, doc_folder_id: doc_folder.id)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user.id)
        |> put_req_header("accept", "application/json")

      params = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        asset_type: "file",
        attachable_type: "doc",
        attachable_id: doc.id
      }

      response =
        conn
        |> post(~p"/api/assets/request-upload", params)
        |> json_response(422)

      assert response["error"] == "Storage quota exceeded"
    end
  end

  describe "confirm" do
    test "marks pending asset as active", %{conn: conn, workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "pending",
          size_bytes: 5000,
          attachable_type: "user",
          attachable_id: user.id
        )

      response =
        conn
        |> post(~p"/api/assets/#{asset.id}/confirm")
        |> json_response(200)

      assert response["data"]["status"] == "active"
      assert response["data"]["id"] == asset.id
    end

    test "rejects confirmation of already active asset", %{
      conn: conn,
      workspace: workspace,
      user: user
    } do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "active",
          attachable_type: "user",
          attachable_id: user.id
        )

      response =
        conn
        |> post(~p"/api/assets/#{asset.id}/confirm")
        |> json_response(422)

      assert response["error"] == "Asset is not pending"
    end

    test "returns 404 for non-existent asset", %{conn: conn} do
      fake_id = UUIDv7.generate()

      response =
        conn
        |> post(~p"/api/assets/#{fake_id}/confirm")
        |> json_response(404)

      assert response["errors"]
    end

    test "returns 404 for asset in different workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      asset =
        insert(:asset,
          workspace_id: other_workspace.id,
          uploaded_by_id: other_user.id,
          status: "pending",
          attachable_type: "user",
          attachable_id: other_user.id
        )

      response =
        conn
        |> post(~p"/api/assets/#{asset.id}/confirm")
        |> json_response(404)

      assert response["errors"]
    end
  end

  describe "show" do
    test "returns asset with download URL", %{conn: conn, workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "active",
          attachable_type: "user",
          attachable_id: user.id
        )

      response =
        conn
        |> get(~p"/api/assets/#{asset.id}")
        |> json_response(200)

      assert response["data"]["id"] == asset.id
      assert response["data"]["filename"] == asset.filename
    end

    test "returns 404 for non-existent asset", %{conn: conn} do
      fake_id = UUIDv7.generate()

      response =
        conn
        |> get(~p"/api/assets/#{fake_id}")
        |> json_response(404)

      assert response["errors"]
    end

    test "returns 404 for asset in different workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      asset =
        insert(:asset,
          workspace_id: other_workspace.id,
          uploaded_by_id: other_user.id,
          attachable_type: "user",
          attachable_id: other_user.id
        )

      response =
        conn
        |> get(~p"/api/assets/#{asset.id}")
        |> json_response(404)

      assert response["errors"]
    end
  end

  describe "delete" do
    test "deletes asset and returns 204", %{conn: conn, workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "active",
          attachable_type: "user",
          attachable_id: user.id
        )

      conn
      |> delete(~p"/api/assets/#{asset.id}")
      |> response(204)

      # Verify it's gone
      response =
        conn
        |> get(~p"/api/assets/#{asset.id}")
        |> json_response(404)

      assert response["errors"]
    end

    test "returns 404 for non-existent asset", %{conn: conn} do
      fake_id = UUIDv7.generate()

      response =
        conn
        |> delete(~p"/api/assets/#{fake_id}")
        |> json_response(404)

      assert response["errors"]
    end

    test "returns 404 for asset in different workspace", %{conn: conn} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      asset =
        insert(:asset,
          workspace_id: other_workspace.id,
          uploaded_by_id: other_user.id,
          attachable_type: "user",
          attachable_id: other_user.id
        )

      response =
        conn
        |> delete(~p"/api/assets/#{asset.id}")
        |> json_response(404)

      assert response["errors"]
    end
  end

  describe "storage" do
    test "returns storage usage for workspace", %{conn: _conn} do
      # Create a fresh workspace with specific storage values
      workspace =
        insert(:workspace, storage_used_bytes: 1_000_000, storage_quota_bytes: 5_368_709_120)

      user = insert(:user, workspace_id: workspace.id)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user.id)
        |> put_req_header("accept", "application/json")

      response =
        conn
        |> get(~p"/api/workspace/storage")
        |> json_response(200)

      assert response["data"]["used_bytes"] == 1_000_000
      assert response["data"]["quota_bytes"] == 5_368_709_120
      assert response["data"]["available_bytes"] == 5_368_709_120 - 1_000_000
    end
  end
end
