defmodule Missionspace.Authorization.Scopes do
  @moduledoc """
  Scope catalog and helpers for role-based and API key authorization.
  """

  alias Missionspace.Accounts.User

  @action_scopes %{
    manage_workspace_members: "workspace:members:manage",
    manage_project_members: "project:members:manage",
    manage_projects: "project:manage",
    manage_item_members: "item:members:manage",
    set_visibility: "item:visibility:set",
    view_project: "project:view",
    view_item: "item:view",
    create_item: "item:create",
    update_item: "item:update",
    delete_item: "item:delete",
    comment: "item:comment",
    view_message: "message:view",
    create_message: "message:create",
    update_message: "message:update",
    delete_message: "message:delete"
  }

  @member_scopes [
                   "project:view",
                   "item:view",
                   "item:create",
                   "item:update",
                   "item:delete",
                   "item:comment",
                   "item:members:manage",
                   "item:visibility:set",
                   "message:view",
                   "message:create",
                   "message:update",
                   "message:delete"
                 ]
                 |> Enum.sort()

  @guest_scopes @member_scopes
  @owner_scopes @action_scopes |> Map.values() |> Enum.uniq() |> Enum.sort()

  @doc """
  Returns all known scopes.
  """
  def all_scopes do
    @owner_scopes
  end

  @doc """
  Returns the required scope for a given action.
  """
  def action_scope(action) when is_atom(action) do
    Map.get(@action_scopes, action)
  end

  def action_scope(_), do: nil

  @doc """
  Returns the allowed scopes for a role.
  """
  def role_scopes("owner"), do: @owner_scopes
  def role_scopes("member"), do: @member_scopes
  def role_scopes("guest"), do: @guest_scopes
  def role_scopes(_), do: []

  @doc """
  Returns true when the user has the scope required by the given action.
  Unknown actions are treated as unrestricted by scope.
  """
  def has_scope_for_action?(%User{} = user, action) do
    case action_scope(action) do
      nil -> true
      scope -> has_scope?(user, scope)
    end
  end

  @doc """
  Returns true when the user has a specific scope.
  """
  def has_scope?(%User{} = user, scope) when is_binary(scope) do
    scope in effective_scopes_for_user(user)
  end

  def has_scope?(_user, _scope), do: false

  @doc """
  Returns user scopes constrained by role.
  If no explicit user scopes are assigned, role scopes are used.
  """
  def effective_scopes_for_user(%User{} = user) do
    allowed = role_scopes(user.role) |> MapSet.new()

    explicit_scopes =
      case user.scopes do
        nil -> MapSet.to_list(allowed)
        scopes -> normalize_scope_list(scopes)
      end

    explicit_scopes
    |> MapSet.new()
    |> MapSet.intersection(allowed)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc """
  Intersects arbitrary scopes with role scopes.
  """
  def intersect_with_role(scopes, role) do
    scopes
    |> normalize_scope_list()
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(role_scopes(role)))
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc """
  Validates that all requested scopes are known and within role limits.
  """
  def valid_role_scopes?(scopes, role) when is_list(scopes) do
    requested = Enum.uniq(scopes)
    requested_set = MapSet.new(requested)
    known_set = MapSet.new(all_scopes())
    allowed_set = MapSet.new(role_scopes(role))

    Enum.all?(requested, &is_binary/1) and
      MapSet.subset?(requested_set, known_set) and
      MapSet.subset?(requested_set, allowed_set)
  end

  def valid_role_scopes?(_scopes, _role), do: false

  @doc """
  Normalizes a scope list by removing invalid values and duplicates.
  """
  def normalize_scope_list(scopes) when is_list(scopes) do
    known_scopes = MapSet.new(all_scopes())

    scopes
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
    |> Enum.filter(&MapSet.member?(known_scopes, &1))
    |> Enum.sort()
  end

  def normalize_scope_list(_), do: []
end
