defmodule Missionspace.ApiKeysTest do
  use Missionspace.DataCase

  alias Missionspace.ApiKeys
  alias Missionspace.Authorization.Scopes

  describe "create_api_key_for_user/2" do
    setup do
      workspace = insert(:workspace)
      member = insert(:user, workspace_id: workspace.id, role: "member")
      owner = insert(:user, workspace_id: workspace.id, role: "owner")

      {:ok, workspace: workspace, member: member, owner: owner}
    end

    test "creates key with role scopes by default", %{member: member} do
      {:ok, %{api_key: api_key, plaintext_key: plaintext_key}} =
        ApiKeys.create_api_key_for_user(member, %{"name" => "CLI"})

      assert String.starts_with?(plaintext_key, ApiKeys.api_key_prefix())
      assert api_key.key_hash != plaintext_key
      assert api_key.scopes == Scopes.role_scopes("member")
    end

    test "creates key with a subset of scopes", %{owner: owner} do
      requested_scopes = ["project:view", "item:view", "item:create"]

      {:ok, %{api_key: api_key}} =
        ApiKeys.create_api_key_for_user(owner, %{
          "name" => "Automation",
          "scopes" => requested_scopes
        })

      assert api_key.scopes == Enum.sort(requested_scopes)
    end

    test "rejects scopes outside role permissions", %{member: member} do
      assert {:error, :invalid_scopes} =
               ApiKeys.create_api_key_for_user(member, %{
                 "name" => "Invalid",
                 "scopes" => ["project:manage"]
               })
    end
  end

  describe "authenticate_api_key/1" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id, role: "member")

      {:ok, %{api_key: api_key, plaintext_key: plaintext_key}} =
        ApiKeys.create_api_key_for_user(user, %{"name" => "CLI"})

      {:ok, user: user, api_key: api_key, plaintext_key: plaintext_key}
    end

    test "authenticates active key", %{user: user, api_key: api_key, plaintext_key: plaintext_key} do
      assert {:ok, %{user: auth_user, api_key: auth_key, scopes: scopes}} =
               ApiKeys.authenticate_api_key(plaintext_key)

      assert auth_user.id == user.id
      assert auth_key.id == api_key.id
      assert scopes == Scopes.role_scopes("member")
    end

    test "returns error for revoked key", %{
      user: user,
      api_key: api_key,
      plaintext_key: plaintext_key
    } do
      assert {:ok, _revoked_key} = ApiKeys.revoke_api_key_for_user(user.id, api_key.id)

      assert {:error, :invalid_api_key} = ApiKeys.authenticate_api_key(plaintext_key)
    end
  end

  describe "reconcile_scopes_for_user_role/2" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id, role: "owner")

      {:ok, %{api_key: api_key}} =
        ApiKeys.create_api_key_for_user(user, %{"name" => "Owner key"})

      {:ok, user: user, api_key: api_key}
    end

    test "removes scopes not allowed by new role", %{user: user, api_key: api_key} do
      assert {:ok, 1} = ApiKeys.reconcile_scopes_for_user_role(user.id, "member")

      updated_key = Missionspace.Repo.get!(Missionspace.ApiKeys.ApiKey, api_key.id)

      assert updated_key.scopes == Scopes.role_scopes("member")
      refute "project:manage" in updated_key.scopes
      refute "workspace:members:manage" in updated_key.scopes
    end
  end

  describe "delete_all_for_user/1" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id, role: "member")

      {:ok, %{plaintext_key: key1}} =
        ApiKeys.create_api_key_for_user(user, %{"name" => "Key 1"})

      {:ok, %{plaintext_key: key2}} =
        ApiKeys.create_api_key_for_user(user, %{"name" => "Key 2"})

      {:ok, user: user, key1: key1, key2: key2}
    end

    test "deletes all keys and invalidates them", %{user: user, key1: key1, key2: key2} do
      assert {:ok, 2} = ApiKeys.delete_all_for_user(user.id)

      assert {:error, :invalid_api_key} = ApiKeys.authenticate_api_key(key1)
      assert {:error, :invalid_api_key} = ApiKeys.authenticate_api_key(key2)
    end
  end
end
