defmodule Bridge.Authorization.PolicyTest do
  use Bridge.DataCase

  alias Bridge.Authorization.Policy

  describe "can?/3 for owners" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      other_owner = insert(:user, workspace_id: workspace.id, role: "owner")
      project = insert(:project, workspace_id: workspace.id)

      # Project doc folder owned by the owner
      doc_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: owner.id)

      doc =
        insert(:doc,
          workspace_id: workspace.id,
          author_id: owner.id,
          doc_folder_id: doc_folder.id
        )

      insert(:project_item,
        project_id: project.id,
        item_type: "doc_folder",
        item_id: doc_folder.id
      )

      {:ok,
       owner: owner,
       other_owner: other_owner,
       workspace: workspace,
       project: project,
       doc: doc,
       doc_folder: doc_folder}
    end

    test "owner can manage workspace and project members", %{owner: owner, project: project} do
      assert Policy.can?(owner, :manage_workspace_members, nil)
      assert Policy.can?(owner, :manage_project_members, project)
      assert Policy.can?(owner, :manage_projects, nil)
    end

    test "owner can view and mutate project items", %{owner: owner, project: project, doc: doc} do
      assert Policy.can?(owner, :view_project, project)
      assert Policy.can?(owner, :view_item, doc)
      assert Policy.can?(owner, :update_item, doc)
      assert Policy.can?(owner, :delete_item, doc)
    end

    test "owner can view all shared non-project items", %{
      owner: owner,
      other_owner: other_owner,
      workspace: workspace
    } do
      # Shared folder created by another owner
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: other_owner.id,
          visibility: "shared"
        )

      doc =
        insert(:doc,
          workspace_id: workspace.id,
          author_id: other_owner.id,
          doc_folder_id: folder.id
        )

      doc = Bridge.Repo.preload(doc, :doc_folder)

      assert Policy.can?(owner, :view_item, doc)
      assert Policy.can?(owner, :view_item, folder)
    end

    test "owner can view own private non-project items", %{owner: owner, workspace: workspace} do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: owner.id,
          visibility: "private"
        )

      doc =
        insert(:doc, workspace_id: workspace.id, author_id: owner.id, doc_folder_id: folder.id)

      doc = Bridge.Repo.preload(doc, :doc_folder)

      assert Policy.can?(owner, :view_item, folder)
      assert Policy.can?(owner, :view_item, doc)
    end

    test "owner CANNOT view other owners' private non-project items", %{
      owner: owner,
      other_owner: other_owner,
      workspace: workspace
    } do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: other_owner.id,
          visibility: "private"
        )

      doc =
        insert(:doc,
          workspace_id: workspace.id,
          author_id: other_owner.id,
          doc_folder_id: folder.id
        )

      doc = Bridge.Repo.preload(doc, :doc_folder)

      refute Policy.can?(owner, :view_item, folder)
      refute Policy.can?(owner, :view_item, doc)
    end

    test "owner can mutate any accessible item (including others' shared)", %{
      owner: owner,
      other_owner: other_owner,
      workspace: workspace
    } do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: other_owner.id,
          visibility: "shared"
        )

      assert Policy.can?(owner, :update_item, folder)
      assert Policy.can?(owner, :delete_item, folder)
    end

    test "owner can set visibility to private", %{owner: owner} do
      assert Policy.can?(owner, :set_visibility, "private")
      assert Policy.can?(owner, :set_visibility, "shared")
    end

    test "owner can manage item members", %{owner: owner} do
      assert Policy.can?(owner, :manage_item_members, nil)
    end
  end

  describe "can?/3 for members" do
    setup do
      workspace = insert(:workspace)
      member = insert(:user, workspace_id: workspace.id, role: "member")
      other_member = insert(:user, workspace_id: workspace.id, role: "member")
      project = insert(:project, workspace_id: workspace.id)
      insert(:project_member, user_id: member.id, project_id: project.id)

      # Project doc folder owned by member
      member_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: member.id)

      member_doc =
        insert(:doc,
          workspace_id: workspace.id,
          author_id: member.id,
          doc_folder_id: member_folder.id
        )

      insert(:project_item,
        project_id: project.id,
        item_type: "doc_folder",
        item_id: member_folder.id
      )

      # Project doc folder owned by other
      other_folder =
        insert(:doc_folder, workspace_id: workspace.id, created_by_id: other_member.id)

      other_doc =
        insert(:doc,
          workspace_id: workspace.id,
          author_id: other_member.id,
          doc_folder_id: other_folder.id
        )

      insert(:project_item,
        project_id: project.id,
        item_type: "doc_folder",
        item_id: other_folder.id
      )

      {:ok,
       member: member,
       other_member: other_member,
       workspace: workspace,
       project: project,
       member_doc: member_doc,
       other_doc: other_doc}
    end

    test "member can view projects they are assigned to", %{member: member, project: project} do
      assert Policy.can?(member, :view_project, project)
    end

    test "member cannot view projects they are not assigned to", %{
      member: member,
      workspace: workspace
    } do
      other_project = insert(:project, workspace_id: workspace.id)
      refute Policy.can?(member, :view_project, other_project)
    end

    test "member can view items in assigned projects", %{member: member, member_doc: doc} do
      assert Policy.can?(member, :view_item, doc)
    end

    test "member can view own non-project items (creator access)", %{
      member: member,
      workspace: workspace
    } do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: member.id,
          visibility: "shared"
        )

      doc =
        insert(:doc, workspace_id: workspace.id, author_id: member.id, doc_folder_id: folder.id)

      doc = Bridge.Repo.preload(doc, :doc_folder)

      assert Policy.can?(member, :view_item, folder)
      assert Policy.can?(member, :view_item, doc)
    end

    test "member can view shared non-project items they are invited to", %{
      member: member,
      other_member: other_member,
      workspace: workspace
    } do
      channel =
        insert(:channel,
          workspace_id: workspace.id,
          created_by_id: other_member.id,
          visibility: "shared"
        )

      insert(:item_member,
        item_type: "channel",
        item_id: channel.id,
        user_id: member.id,
        workspace_id: workspace.id
      )

      assert Policy.can?(member, :view_item, channel)
    end

    test "member cannot view shared non-project items they are NOT invited to", %{
      member: member,
      other_member: other_member,
      workspace: workspace
    } do
      channel =
        insert(:channel,
          workspace_id: workspace.id,
          created_by_id: other_member.id,
          visibility: "shared"
        )

      refute Policy.can?(member, :view_item, channel)
    end

    test "member cannot view others' private non-project items", %{
      member: member,
      other_member: other_member,
      workspace: workspace
    } do
      folder =
        insert(:doc_folder,
          workspace_id: workspace.id,
          created_by_id: other_member.id,
          visibility: "private"
        )

      refute Policy.can?(member, :view_item, folder)
    end

    test "member can update their own items", %{member: member, member_doc: doc} do
      assert Policy.can?(member, :update_item, doc)
    end

    test "member cannot update others' items even in same project", %{
      member: member,
      other_doc: doc
    } do
      refute Policy.can?(member, :update_item, doc)
    end

    test "member can delete their own items", %{member: member, member_doc: doc} do
      assert Policy.can?(member, :delete_item, doc)
    end

    test "member cannot delete others' items", %{member: member, other_doc: doc} do
      refute Policy.can?(member, :delete_item, doc)
    end

    test "member cannot manage workspace members", %{member: member} do
      refute Policy.can?(member, :manage_workspace_members, nil)
    end

    test "member cannot manage project members", %{member: member, project: project} do
      refute Policy.can?(member, :manage_project_members, project)
    end

    test "member can comment on viewable items", %{member: member, member_doc: doc} do
      assert Policy.can?(member, :comment, doc)
    end

    test "member cannot set visibility to private", %{member: member} do
      refute Policy.can?(member, :set_visibility, "private")
      assert Policy.can?(member, :set_visibility, "shared")
    end

    test "member can manage item members on own shared items", %{
      member: member,
      workspace: workspace
    } do
      channel =
        insert(:channel,
          workspace_id: workspace.id,
          created_by_id: member.id,
          visibility: "shared"
        )

      assert Policy.can?(member, :manage_item_members, channel)
    end

    test "member cannot manage item members on others' items", %{
      member: member,
      other_member: other_member,
      workspace: workspace
    } do
      channel =
        insert(:channel,
          workspace_id: workspace.id,
          created_by_id: other_member.id,
          visibility: "shared"
        )

      refute Policy.can?(member, :manage_item_members, channel)
    end

    test "member cannot manage item members on own private items", %{
      member: member,
      workspace: workspace
    } do
      channel =
        insert(:channel,
          workspace_id: workspace.id,
          created_by_id: member.id,
          visibility: "private"
        )

      refute Policy.can?(member, :manage_item_members, channel)
    end
  end

  describe "can?/3 for guests" do
    setup do
      workspace = insert(:workspace)
      guest = insert(:user, workspace_id: workspace.id, role: "guest")
      project = insert(:project, workspace_id: workspace.id)
      insert(:project_member, user_id: guest.id, project_id: project.id)

      other_user = insert(:user, workspace_id: workspace.id, role: "owner")

      guest_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: guest.id)

      guest_doc =
        insert(:doc,
          workspace_id: workspace.id,
          author_id: guest.id,
          doc_folder_id: guest_folder.id
        )

      insert(:project_item,
        project_id: project.id,
        item_type: "doc_folder",
        item_id: guest_folder.id
      )

      other_folder = insert(:doc_folder, workspace_id: workspace.id, created_by_id: other_user.id)

      other_doc =
        insert(:doc,
          workspace_id: workspace.id,
          author_id: other_user.id,
          doc_folder_id: other_folder.id
        )

      insert(:project_item,
        project_id: project.id,
        item_type: "doc_folder",
        item_id: other_folder.id
      )

      {:ok,
       guest: guest,
       workspace: workspace,
       project: project,
       guest_doc: guest_doc,
       other_doc: other_doc}
    end

    test "guest can view assigned project", %{guest: guest, project: project} do
      assert Policy.can?(guest, :view_project, project)
    end

    test "guest cannot view other projects", %{guest: guest, workspace: workspace} do
      other_project = insert(:project, workspace_id: workspace.id)
      refute Policy.can?(guest, :view_project, other_project)
    end

    test "guest can view items in assigned project", %{guest: guest, guest_doc: doc} do
      assert Policy.can?(guest, :view_item, doc)
    end

    test "guest can update their own items", %{guest: guest, guest_doc: doc} do
      assert Policy.can?(guest, :update_item, doc)
    end

    test "guest cannot update others' items", %{guest: guest, other_doc: doc} do
      refute Policy.can?(guest, :update_item, doc)
    end

    test "guest cannot manage workspace members", %{guest: guest} do
      refute Policy.can?(guest, :manage_workspace_members, nil)
    end

    test "guest cannot manage project members", %{guest: guest, project: project} do
      refute Policy.can?(guest, :manage_project_members, project)
    end
  end

  describe "can?/3 for create_item" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      member = insert(:user, workspace_id: workspace.id, role: "member")
      guest = insert(:user, workspace_id: workspace.id, role: "guest")
      project = insert(:project, workspace_id: workspace.id)
      insert(:project_member, user_id: member.id, project_id: project.id)
      insert(:project_member, user_id: guest.id, project_id: project.id)

      {:ok, owner: owner, member: member, guest: guest, workspace: workspace, project: project}
    end

    test "all roles can create workspace-level items (nil project)", %{
      owner: owner,
      member: member,
      guest: guest
    } do
      assert Policy.can?(owner, :create_item, nil)
      assert Policy.can?(member, :create_item, nil)
      assert Policy.can?(guest, :create_item, nil)
    end

    test "member can create items in assigned projects", %{member: member, project: project} do
      assert Policy.can?(member, :create_item, project.id)
    end

    test "member cannot create items in unassigned projects", %{
      member: member,
      workspace: workspace
    } do
      other_project = insert(:project, workspace_id: workspace.id)
      refute Policy.can?(member, :create_item, other_project.id)
    end

    test "owner can create items in any project", %{owner: owner, workspace: workspace} do
      any_project = insert(:project, workspace_id: workspace.id)
      assert Policy.can?(owner, :create_item, any_project.id)
    end
  end

  describe "scope gating" do
    setup do
      workspace = insert(:workspace)
      owner = insert(:user, workspace_id: workspace.id, role: "owner")
      project = insert(:project, workspace_id: workspace.id)

      {:ok, owner: owner, project: project}
    end

    test "denies action when required scope is missing", %{owner: owner} do
      owner_without_manage_scope = %{owner | scopes: ["item:view"]}

      refute Policy.can?(owner_without_manage_scope, :manage_projects, nil)
    end

    test "allows action when required scope is present", %{owner: owner, project: project} do
      owner_with_project_view = %{owner | scopes: ["project:view"]}

      assert Policy.can?(owner_with_project_view, :view_project, project)
    end
  end
end
