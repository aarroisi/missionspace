defmodule Bridge.NamespacesTest do
  use Bridge.DataCase

  import Bridge.Factory

  alias Bridge.Namespaces

  setup do
    workspace = insert(:workspace)
    %{workspace: workspace}
  end

  describe "reserve_prefix/4" do
    test "creates a prefix record", %{workspace: workspace} do
      entity_id = UUIDv7.generate()

      assert {:ok, prefix} =
               Namespaces.reserve_prefix("AB", "list", entity_id, workspace.id)

      assert prefix.prefix == "AB"
      assert prefix.entity_type == "list"
      assert prefix.entity_id == entity_id
      assert prefix.workspace_id == workspace.id
    end

    test "fails on duplicate (workspace_id, prefix)", %{workspace: workspace} do
      entity_id_1 = UUIDv7.generate()
      entity_id_2 = UUIDv7.generate()

      assert {:ok, _} = Namespaces.reserve_prefix("DUP", "list", entity_id_1, workspace.id)

      assert {:error, changeset} =
               Namespaces.reserve_prefix("DUP", "doc_folder", entity_id_2, workspace.id)

      assert "this prefix is already in use" in errors_on(changeset).workspace_id
    end

    test "allows same prefix in different workspaces" do
      workspace_a = insert(:workspace)
      workspace_b = insert(:workspace)
      entity_a = UUIDv7.generate()
      entity_b = UUIDv7.generate()

      assert {:ok, _} = Namespaces.reserve_prefix("XY", "list", entity_a, workspace_a.id)
      assert {:ok, _} = Namespaces.reserve_prefix("XY", "list", entity_b, workspace_b.id)
    end
  end

  describe "release_prefix/2" do
    test "deletes prefix records for entity", %{workspace: workspace} do
      entity_id = UUIDv7.generate()
      {:ok, _} = Namespaces.reserve_prefix("RL", "list", entity_id, workspace.id)

      assert :ok = Namespaces.release_prefix("list", entity_id)

      # The prefix should now be available
      assert Namespaces.check_prefix_available?("RL", workspace.id)
    end
  end

  describe "check_prefix_available?/2" do
    test "returns true when prefix is available", %{workspace: workspace} do
      assert Namespaces.check_prefix_available?("ZZ", workspace.id)
    end

    test "returns false when prefix is taken", %{workspace: workspace} do
      entity_id = UUIDv7.generate()
      {:ok, _} = Namespaces.reserve_prefix("TK", "list", entity_id, workspace.id)

      refute Namespaces.check_prefix_available?("TK", workspace.id)
    end
  end

  describe "suggest_prefix/2" do
    test "generates prefix from name", %{workspace: workspace} do
      prefix = Namespaces.suggest_prefix("My Documents", workspace.id)

      assert is_binary(prefix)
      assert String.length(prefix) >= 2
      assert String.length(prefix) <= 5
      assert prefix =~ ~r/^[A-Z0-9]+$/
    end

    test "avoids collisions with existing prefixes", %{workspace: workspace} do
      entity_id = UUIDv7.generate()
      # Reserve the most obvious prefix for "My Documents" -> "MD"
      {:ok, _} = Namespaces.reserve_prefix("MD", "list", entity_id, workspace.id)

      prefix = Namespaces.suggest_prefix("My Documents", workspace.id)

      # The suggestion must not be the already-taken "MD"
      refute prefix == "MD"
      assert Namespaces.check_prefix_available?(prefix, workspace.id)
    end

    test "generates valid prefix for single-word name", %{workspace: workspace} do
      prefix = Namespaces.suggest_prefix("Tasks", workspace.id)

      assert is_binary(prefix)
      assert String.length(prefix) >= 2
    end
  end

  describe "cross-type collision" do
    test "prefix reserved for list blocks doc_folder from using same prefix", %{
      workspace: workspace
    } do
      entity_id = UUIDv7.generate()
      {:ok, _} = Namespaces.reserve_prefix("CR", "list", entity_id, workspace.id)

      # The shared namespace check does not distinguish by entity type
      refute Namespaces.check_prefix_available?("CR", workspace.id)

      # Trying to reserve the same prefix for a doc_folder should fail
      doc_folder_id = UUIDv7.generate()

      assert {:error, changeset} =
               Namespaces.reserve_prefix("CR", "doc_folder", doc_folder_id, workspace.id)

      assert "this prefix is already in use" in errors_on(changeset).workspace_id
    end
  end
end
