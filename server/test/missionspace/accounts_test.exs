defmodule Missionspace.AccountsTest do
  use Missionspace.DataCase

  alias Missionspace.Accounts
  alias Missionspace.Accounts.User
  alias Missionspace.ApiKeys
  alias Missionspace.Projects
  alias Missionspace.Notifications

  describe "delete_user/1 (soft delete)" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id, role: "member")
      owner = insert(:user, workspace_id: workspace.id, role: "owner")

      {:ok, workspace: workspace, user: user, owner: owner}
    end

    test "marks user as inactive", %{user: user} do
      assert user.is_active == true

      {:ok, deleted_user} = Accounts.delete_user(user)

      assert deleted_user.is_active == false
      assert deleted_user.deleted_at != nil
    end

    test "scrubs email to free it for reuse", %{user: user} do
      original_email = user.email

      {:ok, deleted_user} = Accounts.delete_user(user)

      assert deleted_user.email == "deleted_#{user.id}@deleted.local"
      assert deleted_user.email != original_email
    end

    test "preserves user record in database", %{user: user} do
      {:ok, _deleted_user} = Accounts.delete_user(user)

      # User record should still exist
      assert {:ok, found_user} = Accounts.get_user(user.id)
      assert found_user.id == user.id
      assert found_user.is_active == false
    end

    test "removes project memberships", %{workspace: workspace, user: user} do
      project = insert(:project, workspace_id: workspace.id)
      {:ok, _} = Projects.add_member(project.id, user.id)

      # Verify membership exists
      assert Projects.is_member?(project.id, user.id)

      {:ok, _deleted_user} = Accounts.delete_user(user)

      # Membership should be removed
      refute Projects.is_member?(project.id, user.id)
    end

    test "removes notifications where user is recipient", %{
      workspace: workspace,
      user: user,
      owner: owner
    } do
      notification = insert(:notification, user_id: user.id, actor_id: owner.id)

      {:ok, _deleted_user} = Accounts.delete_user(user)

      # Notification should be deleted
      assert {:error, :not_found} = Notifications.get_notification(notification.id)
    end

    test "removes notifications where user is actor", %{
      workspace: workspace,
      user: user,
      owner: owner
    } do
      notification = insert(:notification, user_id: owner.id, actor_id: user.id)

      {:ok, _deleted_user} = Accounts.delete_user(user)

      # Notification should be deleted
      assert {:error, :not_found} = Notifications.get_notification(notification.id)
    end

    test "preserves messages created by user", %{workspace: workspace, user: user} do
      channel = insert(:channel, workspace_id: workspace.id)
      message = insert(:message, user_id: user.id, entity_type: "channel", entity_id: channel.id)

      {:ok, _deleted_user} = Accounts.delete_user(user)

      # Message should still exist
      assert {:ok, found_message} = Missionspace.Chat.get_message(message.id)
      assert found_message.user_id == user.id
    end

    test "preserves tasks created by user", %{workspace: workspace, user: user} do
      list = insert(:list, workspace_id: workspace.id, created_by_id: user.id)
      task = insert(:task, list_id: list.id, created_by_id: user.id)

      {:ok, _deleted_user} = Accounts.delete_user(user)

      # Task should still exist with created_by reference
      assert {:ok, found_task} = Missionspace.Lists.get_task(task.id)
      assert found_task.created_by_id == user.id
    end

    test "preserves docs created by user", %{workspace: workspace, user: user} do
      doc_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: user.id)

      doc =
        insert(:doc, workspace_id: workspace.id, author_id: user.id, doc_folder_id: doc_folder.id)

      {:ok, _deleted_user} = Accounts.delete_user(user)

      # Doc should still exist with author reference
      assert {:ok, found_doc} = Missionspace.Docs.get_doc(doc.id, workspace.id)
      assert found_doc.author_id == user.id
    end

    test "removes item memberships", %{workspace: workspace, user: user} do
      channel = insert(:channel, workspace_id: workspace.id, created_by_id: user.id)

      insert(:item_member,
        item_type: "channel",
        item_id: channel.id,
        user_id: user.id,
        workspace_id: workspace.id
      )

      assert Projects.is_item_member?("channel", channel.id, user.id)

      {:ok, _deleted_user} = Accounts.delete_user(user)

      refute Projects.is_item_member?("channel", channel.id, user.id)
    end

    test "removes API keys and invalidates them", %{user: user} do
      {:ok, %{plaintext_key: plaintext_key}} =
        ApiKeys.create_api_key_for_user(user, %{"name" => "Automation"})

      assert {:ok, _deleted_user} = Accounts.delete_user(user)

      assert {:error, :invalid_api_key} = ApiKeys.authenticate_api_key(plaintext_key)
    end
  end

  describe "update_user/2 demotion side-effects" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")

      {:ok, workspace: workspace, owner: owner}
    end

    test "demoting owner to member forces private items to shared", %{
      workspace: workspace,
      owner: owner
    } do
      private_list =
        insert(:list, workspace_id: workspace.id, created_by_id: owner.id, visibility: "private")

      private_folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: owner.id,
          visibility: "private"
        )

      private_channel =
        insert(:channel,
          workspace_id: workspace.id,
          created_by_id: owner.id,
          visibility: "private"
        )

      shared_list =
        insert(:list, workspace_id: workspace.id, created_by_id: owner.id, visibility: "shared")

      {:ok, updated_user} = Accounts.update_user(owner, %{role: "member"})

      assert updated_user.role == "member"

      # Private items should now be shared
      assert Missionspace.Repo.get!(Missionspace.Lists.List, private_list.id).visibility ==
               "shared"

      assert Missionspace.Repo.get!(Missionspace.Docs.DocFolder, private_folder.id).visibility ==
               "shared"

      assert Missionspace.Repo.get!(Missionspace.Chat.Channel, private_channel.id).visibility ==
               "shared"

      # Already shared items remain shared
      assert Missionspace.Repo.get!(Missionspace.Lists.List, shared_list.id).visibility ==
               "shared"
    end

    test "demoting owner to guest forces private items to shared", %{
      workspace: workspace,
      owner: owner
    } do
      private_list =
        insert(:list, workspace_id: workspace.id, created_by_id: owner.id, visibility: "private")

      {:ok, updated_user} = Accounts.update_user(owner, %{role: "guest"})

      assert updated_user.role == "guest"

      assert Missionspace.Repo.get!(Missionspace.Lists.List, private_list.id).visibility ==
               "shared"
    end

    test "changing member to guest does NOT force visibility change", %{workspace: workspace} do
      member = insert(:user, workspace_id: workspace.id, role: "member")

      list =
        insert(:list, workspace_id: workspace.id, created_by_id: member.id, visibility: "shared")

      {:ok, updated_user} = Accounts.update_user(member, %{role: "guest"})

      assert updated_user.role == "guest"
      assert Missionspace.Repo.get!(Missionspace.Lists.List, list.id).visibility == "shared"
    end

    test "non-role updates do not trigger demotion side-effects", %{
      workspace: workspace,
      owner: owner
    } do
      private_list =
        insert(:list, workspace_id: workspace.id, created_by_id: owner.id, visibility: "private")

      {:ok, updated_user} = Accounts.update_user(owner, %{name: "New Name"})

      assert updated_user.name == "New Name"
      assert updated_user.role == "owner"

      assert Missionspace.Repo.get!(Missionspace.Lists.List, private_list.id).visibility ==
               "private"
    end

    test "role changes reconcile API key scopes", %{owner: owner} do
      {:ok, %{api_key: api_key}} =
        ApiKeys.create_api_key_for_user(owner, %{"name" => "Owner key"})

      {:ok, _updated_user} = Accounts.update_user(owner, %{role: "member"})

      reloaded_key = Missionspace.Repo.get!(Missionspace.ApiKeys.ApiKey, api_key.id)

      assert reloaded_key.scopes == Missionspace.Authorization.Scopes.role_scopes("member")
      refute "project:manage" in reloaded_key.scopes
      refute "workspace:members:manage" in reloaded_key.scopes
    end
  end

  describe "list_workspace_users/1" do
    setup do
      workspace = insert(:workspace)
      active_user = insert(:user, workspace_id: workspace.id, role: "member", is_active: true)
      inactive_user = insert(:user, workspace_id: workspace.id, role: "member", is_active: false)

      {:ok, workspace: workspace, active_user: active_user, inactive_user: inactive_user}
    end

    test "only returns active users", %{
      workspace: workspace,
      active_user: active_user,
      inactive_user: inactive_user
    } do
      users = Accounts.list_workspace_users(workspace.id)

      user_ids = Enum.map(users, & &1.id)
      assert active_user.id in user_ids
      refute inactive_user.id in user_ids
    end
  end

  describe "authenticate_user/2" do
    setup do
      workspace = insert(:workspace)

      active_user =
        insert(:user,
          workspace_id: workspace.id,
          email: "active@example.com",
          password_hash: User.hash_password("password123"),
          is_active: true
        )

      inactive_user =
        insert(:user,
          workspace_id: workspace.id,
          email: "inactive@example.com",
          password_hash: User.hash_password("password123"),
          is_active: false
        )

      {:ok, active_user: active_user, inactive_user: inactive_user}
    end

    test "allows active users to authenticate", %{active_user: active_user} do
      assert {:ok, user} = Accounts.authenticate_user("active@example.com", "password123")
      assert user.id == active_user.id
    end

    test "denies inactive users from authenticating", %{inactive_user: _inactive_user} do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("inactive@example.com", "password123")
    end

    test "denies with wrong password", %{active_user: _active_user} do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("active@example.com", "wrongpassword")
    end

    test "denies with non-existent email" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("nonexistent@example.com", "password123")
    end
  end
end
