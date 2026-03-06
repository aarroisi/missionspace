defmodule Missionspace.AssetsTest do
  use Missionspace.DataCase

  alias Missionspace.Assets

  describe "create_pending_asset/1" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      doc_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id)

      doc =
        insert(:doc, workspace_id: workspace.id, author_id: user.id, doc_folder_id: doc_folder.id)

      {:ok, workspace: workspace, user: user, doc: doc}
    end

    test "creates a pending asset with valid attrs", %{workspace: workspace, user: user, doc: doc} do
      attrs = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        storage_key: "#{workspace.id}/file/2026/02/test.png",
        asset_type: "file",
        workspace_id: workspace.id,
        uploaded_by_id: user.id,
        attachable_type: "doc",
        attachable_id: doc.id
      }

      assert {:ok, asset} = Assets.create_pending_asset(attrs)
      assert asset.filename == "test.png"
      assert asset.status == "pending"
      assert asset.workspace_id == workspace.id
      assert asset.attachable_type == "doc"
      assert asset.attachable_id == doc.id
    end

    test "rejects when attachable_type is missing", %{workspace: workspace, user: user} do
      attrs = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        storage_key: "#{workspace.id}/file/2026/02/test.png",
        asset_type: "file",
        workspace_id: workspace.id,
        uploaded_by_id: user.id
      }

      assert {:error, :attachable_type_required} = Assets.create_pending_asset(attrs)
    end

    test "rejects when attachable_id is missing", %{workspace: workspace, user: user} do
      attrs = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        storage_key: "#{workspace.id}/file/2026/02/test.png",
        asset_type: "file",
        workspace_id: workspace.id,
        uploaded_by_id: user.id,
        attachable_type: "doc"
      }

      assert {:error, :attachable_id_required} = Assets.create_pending_asset(attrs)
    end

    test "rejects when attachable item not in workspace", %{workspace: workspace, user: user} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      other_doc_folder =
        insert(:doc_folder, workspace_id: other_workspace.id, created_by_id: other_user.id)

      other_doc =
        insert(:doc,
          workspace_id: other_workspace.id,
          author_id: other_user.id,
          doc_folder_id: other_doc_folder.id
        )

      attrs = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 1000,
        storage_key: "#{workspace.id}/file/2026/02/test.png",
        asset_type: "file",
        workspace_id: workspace.id,
        uploaded_by_id: user.id,
        attachable_type: "doc",
        attachable_id: other_doc.id
      }

      assert {:error, :attachable_not_found} = Assets.create_pending_asset(attrs)
    end

    test "rejects file that exceeds avatar size limit", %{workspace: workspace, user: user} do
      attrs = %{
        filename: "large.png",
        content_type: "image/png",
        size_bytes: 10 * 1024 * 1024,
        storage_key: "#{workspace.id}/avatar/2026/02/large.png",
        asset_type: "avatar",
        workspace_id: workspace.id,
        uploaded_by_id: user.id,
        attachable_type: "user",
        attachable_id: user.id
      }

      assert {:error, :file_too_large} = Assets.create_pending_asset(attrs)
    end

    test "rejects file that exceeds file size limit", %{
      workspace: workspace,
      user: user,
      doc: doc
    } do
      attrs = %{
        filename: "large.pdf",
        content_type: "application/pdf",
        size_bytes: 30 * 1024 * 1024,
        storage_key: "#{workspace.id}/file/2026/02/large.pdf",
        asset_type: "file",
        workspace_id: workspace.id,
        uploaded_by_id: user.id,
        attachable_type: "doc",
        attachable_id: doc.id
      }

      assert {:error, :file_too_large} = Assets.create_pending_asset(attrs)
    end

    test "rejects file when storage quota exceeded" do
      # Create workspace with storage almost full
      workspace = insert(:workspace, storage_used_bytes: 5_368_709_120 - 1000)
      user = insert(:user, workspace_id: workspace.id)
      doc_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id)

      doc =
        insert(:doc, workspace_id: workspace.id, author_id: user.id, doc_folder_id: doc_folder.id)

      attrs = %{
        filename: "test.png",
        content_type: "image/png",
        size_bytes: 2000,
        storage_key: "#{workspace.id}/file/2026/02/test.png",
        asset_type: "file",
        workspace_id: workspace.id,
        uploaded_by_id: user.id,
        attachable_type: "doc",
        attachable_id: doc.id
      }

      assert {:error, :storage_quota_exceeded} = Assets.create_pending_asset(attrs)
    end
  end

  describe "confirm_upload/2" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)

      {:ok, workspace: workspace, user: user}
    end

    test "marks asset as active and updates storage usage", %{workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "pending",
          size_bytes: 5000,
          attachable_type: "user",
          attachable_id: user.id
        )

      assert {:ok, confirmed} = Assets.confirm_upload(asset.id, workspace.id)
      assert confirmed.status == "active"

      # Verify storage was updated
      {:ok, usage} = Assets.get_storage_usage(workspace.id)
      assert usage.used_bytes == 5000
    end

    test "rejects confirmation of already active asset", %{workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "active",
          size_bytes: 5000,
          attachable_type: "user",
          attachable_id: user.id
        )

      assert {:error, :invalid_status} = Assets.confirm_upload(asset.id, workspace.id)
    end

    test "returns error for non-existent asset", %{workspace: workspace} do
      assert {:error, :not_found} =
               Assets.confirm_upload(UUIDv7.generate(), workspace.id)
    end
  end

  describe "delete_asset/1" do
    setup do
      workspace = insert(:workspace, storage_used_bytes: 10000)
      user = insert(:user, workspace_id: workspace.id)

      {:ok, workspace: workspace, user: user}
    end

    test "deletes asset and reclaims storage for active assets", %{
      workspace: workspace,
      user: user
    } do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "active",
          size_bytes: 5000,
          attachable_type: "user",
          attachable_id: user.id
        )

      assert {:ok, _deleted} = Assets.delete_asset(asset)

      # Asset should be gone
      assert {:error, :not_found} = Assets.get_asset(asset.id, workspace.id)

      # Storage should be reclaimed
      {:ok, usage} = Assets.get_storage_usage(workspace.id)
      assert usage.used_bytes == 5000
    end

    test "deletes pending asset without affecting storage", %{workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "pending",
          size_bytes: 5000,
          attachable_type: "user",
          attachable_id: user.id
        )

      assert {:ok, _deleted} = Assets.delete_asset(asset)

      # Storage should remain unchanged
      {:ok, usage} = Assets.get_storage_usage(workspace.id)
      assert usage.used_bytes == 10000
    end
  end

  describe "get_asset/2" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)

      {:ok, workspace: workspace, user: user}
    end

    test "returns asset when found", %{workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          attachable_type: "user",
          attachable_id: user.id
        )

      assert {:ok, found} = Assets.get_asset(asset.id, workspace.id)
      assert found.id == asset.id
    end

    test "returns error when asset not found", %{workspace: workspace} do
      assert {:error, :not_found} = Assets.get_asset(UUIDv7.generate(), workspace.id)
    end

    test "returns error when asset in different workspace", %{workspace: _workspace, user: _user} do
      other_workspace = insert(:workspace)
      other_user = insert(:user, workspace_id: other_workspace.id)

      asset =
        insert(:asset,
          workspace_id: other_workspace.id,
          uploaded_by_id: other_user.id,
          attachable_type: "user",
          attachable_id: other_user.id
        )

      # Try to access with wrong workspace
      assert {:error, :not_found} = Assets.get_asset(asset.id, UUIDv7.generate())
    end
  end

  describe "get_active_asset/2" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)

      {:ok, workspace: workspace, user: user}
    end

    test "returns active asset", %{workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "active",
          attachable_type: "user",
          attachable_id: user.id
        )

      assert {:ok, found} = Assets.get_active_asset(asset.id, workspace.id)
      assert found.id == asset.id
    end

    test "returns error for pending asset", %{workspace: workspace, user: user} do
      asset =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "pending",
          attachable_type: "user",
          attachable_id: user.id
        )

      assert {:error, :not_found} = Assets.get_active_asset(asset.id, workspace.id)
    end
  end

  describe "get_storage_usage/1" do
    test "returns storage usage for workspace" do
      workspace =
        insert(:workspace,
          storage_used_bytes: 1_000_000,
          storage_quota_bytes: 5_368_709_120
        )

      assert {:ok, usage} = Assets.get_storage_usage(workspace.id)
      assert usage.used_bytes == 1_000_000
      assert usage.quota_bytes == 5_368_709_120
      assert usage.available_bytes == 5_368_709_120 - 1_000_000
    end

    test "returns error for non-existent workspace" do
      assert {:error, :not_found} = Assets.get_storage_usage(UUIDv7.generate())
    end
  end

  describe "list_assets/2" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)

      {:ok, workspace: workspace, user: user}
    end

    test "returns active assets by default", %{workspace: workspace, user: user} do
      active =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "active",
          attachable_type: "user",
          attachable_id: user.id
        )

      _pending =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          status: "pending",
          attachable_type: "user",
          attachable_id: user.id
        )

      assets = Assets.list_assets(workspace.id)

      assert length(assets) == 1
      assert hd(assets).id == active.id
    end

    test "filters by asset_type", %{workspace: workspace, user: user} do
      avatar =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          asset_type: "avatar",
          status: "active",
          attachable_type: "user",
          attachable_id: user.id
        )

      _file =
        insert(:asset,
          workspace_id: workspace.id,
          uploaded_by_id: user.id,
          asset_type: "file",
          status: "active",
          attachable_type: "user",
          attachable_id: user.id
        )

      assets = Assets.list_assets(workspace.id, asset_type: "avatar")

      assert length(assets) == 1
      assert hd(assets).id == avatar.id
    end
  end

  describe "file size limits" do
    test "max_avatar_size returns 5MB" do
      assert Assets.max_avatar_size() == 5 * 1024 * 1024
    end

    test "max_file_size returns 25MB" do
      assert Assets.max_file_size() == 25 * 1024 * 1024
    end
  end
end
