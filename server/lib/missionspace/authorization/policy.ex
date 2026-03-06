defmodule Missionspace.Authorization.Policy do
  @moduledoc """
  Authorization policy module that determines if a user can perform an action on a resource.

  Roles:
  - owner: Access to all shared items + own private items. Can mutate any accessible item.
  - member: Access to project items (via membership) + own items + invited shared items.
           Can only mutate own items.
  - guest: Same as member but limited to one project or item total.
  """

  alias Missionspace.Accounts.User
  alias Missionspace.Authorization.Scopes
  alias Missionspace.Projects

  @doc """
  Check if a user can perform an action on a resource.
  Returns true if allowed, false otherwise.
  """
  def can?(user, action, resource \\ nil)

  def can?(%User{} = user, action, resource) do
    if Scopes.has_scope_for_action?(user, action) do
      do_can?(user, action, resource)
    else
      false
    end
  end

  def can?(_user, _action, _resource), do: false

  # --- Workspace management: owner only ---
  defp do_can?(%User{role: "owner"}, :manage_workspace_members, _), do: true
  defp do_can?(_user, :manage_workspace_members, _), do: false

  # --- Project member management: owner only ---
  defp do_can?(%User{role: "owner"}, :manage_project_members, _), do: true
  defp do_can?(_user, :manage_project_members, _), do: false

  # --- Project management (create/update/delete projects): owner only ---
  defp do_can?(%User{role: "owner"}, :manage_projects, _), do: true
  defp do_can?(_user, :manage_projects, _), do: false

  # --- Item member management: owner or item creator (if shared) ---
  defp do_can?(%User{role: "owner"}, :manage_item_members, _), do: true

  defp do_can?(user, :manage_item_members, item) do
    is_creator?(user, item) and get_visibility(item) == "shared"
  end

  # --- Visibility management: only owner can set private ---
  defp do_can?(%User{role: "owner"}, :set_visibility, _), do: true
  defp do_can?(_user, :set_visibility, "shared"), do: true
  defp do_can?(_user, :set_visibility, _), do: false

  # --- View project ---
  defp do_can?(%User{role: "owner"}, :view_project, _project), do: true

  defp do_can?(user, :view_project, project) do
    is_project_member?(user, project.id)
  end

  # --- View item ---
  defp do_can?(user, :view_item, item) do
    can_access_item?(user, item)
  end

  # --- Create item ---
  # Create without project (workspace-level): allowed for all roles
  defp do_can?(_user, :create_item, nil), do: true
  # Create in project: owner always, others need membership
  defp do_can?(%User{role: "owner"}, :create_item, _project_id), do: true

  defp do_can?(user, :create_item, project_id) when is_binary(project_id) do
    is_project_member?(user, project_id)
  end

  # --- Update item ---
  defp do_can?(user, :update_item, item) do
    can_mutate_item?(user, item)
  end

  # --- Delete item ---
  defp do_can?(user, :delete_item, item) do
    can_mutate_item?(user, item)
  end

  # --- Comment: can view = can comment ---
  defp do_can?(user, :comment, item) do
    can_access_item?(user, item)
  end

  # Default deny
  defp do_can?(_user, _action, _resource), do: false

  # ============================================================
  # Private helpers
  # ============================================================

  # Unified access check for an item.
  # Two paths: project item vs non-project item.
  defp can_access_item?(user, item) do
    case get_project_id(item) do
      nil -> can_access_non_project_item?(user, item)
      project_id -> can_access_project_item?(user, project_id)
    end
  end

  # Project items: owner always, others need project membership
  defp can_access_project_item?(%User{role: "owner"}, _project_id), do: true

  defp can_access_project_item?(user, project_id) do
    is_project_member?(user, project_id)
  end

  # Non-project items: check visibility rules
  defp can_access_non_project_item?(user, item) do
    cond do
      # Creator always has access to their own items
      is_creator?(user, item) -> true
      # Private: only creator (handled above, so deny here)
      get_visibility(item) == "private" -> false
      # Shared: owners have access to all shared items
      user.role == "owner" -> true
      # Shared: invited members/guests have access
      is_item_member?(user, item) -> true
      # Otherwise deny
      true -> false
    end
  end

  # Mutation check: access + ownership constraint for non-owners
  defp can_mutate_item?(%User{role: "owner"} = user, item) do
    can_access_item?(user, item)
  end

  defp can_mutate_item?(user, item) do
    can_access_item?(user, item) and is_creator?(user, item)
  end

  # --- Existing helpers ---

  defp is_project_member?(%User{id: user_id}, project_id) when not is_nil(project_id) do
    Projects.is_member?(project_id, user_id)
  end

  defp is_project_member?(_user, _project_id), do: false

  defp is_creator?(%User{id: user_id}, item) do
    get_creator_id(item) == user_id
  end

  defp get_creator_id(%{author_id: author_id}), do: author_id
  defp get_creator_id(%{created_by_id: created_by_id}), do: created_by_id
  defp get_creator_id(_), do: nil

  # --- New helpers ---

  defp get_visibility(%{visibility: v}) when is_binary(v), do: v
  # Docs inherit visibility from their folder (must be preloaded)
  defp get_visibility(%Missionspace.Docs.Doc{doc_folder: %{visibility: v}}), do: v
  # Tasks inherit visibility from their list (must be preloaded)
  defp get_visibility(%Missionspace.Lists.Task{list: %{visibility: v}}), do: v
  # Fallback for items without visibility field
  defp get_visibility(_), do: "shared"

  defp is_item_member?(%User{id: user_id}, item) do
    {item_type, item_id} = get_item_type_and_id(item)

    if item_type && item_id do
      Projects.is_item_member?(item_type, item_id, user_id)
    else
      false
    end
  end

  defp get_item_type_and_id(%Missionspace.Lists.List{id: id}), do: {"list", id}
  defp get_item_type_and_id(%Missionspace.Docs.DocFolder{id: id}), do: {"doc_folder", id}
  defp get_item_type_and_id(%Missionspace.Chat.Channel{id: id}), do: {"channel", id}
  defp get_item_type_and_id(%Missionspace.Docs.Doc{doc_folder_id: fid}), do: {"doc_folder", fid}
  defp get_item_type_and_id(%Missionspace.Lists.Task{list_id: lid}), do: {"list", lid}
  defp get_item_type_and_id(_), do: {nil, nil}

  # Helper: Get project_id from item using project_items lookup
  defp get_project_id(%Missionspace.Docs.DocFolder{id: id}),
    do: Projects.get_item_project_id("doc_folder", id)

  defp get_project_id(%Missionspace.Docs.Doc{doc_folder_id: folder_id}),
    do: Projects.get_item_project_id("doc_folder", folder_id)

  defp get_project_id(%Missionspace.Lists.List{id: id}),
    do: Projects.get_item_project_id("list", id)

  defp get_project_id(%Missionspace.Chat.Channel{id: id}),
    do: Projects.get_item_project_id("channel", id)

  # For tasks, look up via the list's project
  defp get_project_id(%Missionspace.Lists.Task{list_id: list_id}),
    do: Projects.get_item_project_id("list", list_id)

  defp get_project_id(_), do: nil
end
