defmodule Bridge.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo

  alias Bridge.Projects.Project
  alias Bridge.Projects.ProjectMember
  alias Bridge.Projects.ProjectItem
  alias Bridge.Authorization

  @doc """
  Returns the list of projects for a workspace, filtered by user access.

  ## Examples

      iex> list_projects(workspace_id, user)
      [%Project{}, ...]

  """
  def list_projects(workspace_id, user, opts \\ []) do
    Project
    |> where([p], p.workspace_id == ^workspace_id)
    |> filter_by_user_access(user)
    |> order_by([p], desc: p.id)
    |> preload(:created_by)
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  defp filter_by_user_access(query, user) do
    case Authorization.accessible_project_ids(user) do
      :all -> query
      project_ids -> where(query, [p], p.id in ^project_ids)
    end
  end

  @doc """
  Returns the list of projects with their items preloaded for a workspace, filtered by user access.

  ## Examples

      iex> list_projects_with_items(workspace_id, user)
      [%Project{project_items: [...]}, ...]

  """
  def list_projects_with_items(workspace_id, user, opts \\ []) do
    Project
    |> where([p], p.workspace_id == ^workspace_id)
    |> filter_by_user_access(user)
    |> order_by([p], desc: p.id)
    |> preload([:project_items, :created_by])
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  @doc """
  Returns the list of starred projects for a workspace, filtered by user access.

  ## Examples

      iex> list_starred_projects(workspace_id, user)
      [%Project{}, ...]

  """
  def list_starred_projects(workspace_id, user, opts \\ []) do
    starred_ids = Bridge.Stars.starred_ids(user.id, "project")

    if MapSet.size(starred_ids) == 0 do
      %{entries: [], metadata: %{after: nil, before: nil, limit: 50}}
    else
      ids = MapSet.to_list(starred_ids)

      Project
      |> where([p], p.id in ^ids and p.workspace_id == ^workspace_id)
      |> filter_by_user_access(user)
      |> order_by([p], desc: p.id)
      |> preload(:created_by)
      |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
    end
  end

  @doc """
  Gets a single project within a workspace.

  Returns `{:ok, project}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_project(id, workspace_id)
      {:ok, %Project{}}

      iex> get_project(456, workspace_id)
      {:error, :not_found}

  """
  def get_project(id, workspace_id) do
    case Project
         |> where([p], p.workspace_id == ^workspace_id)
         |> preload(:created_by)
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  @doc """
  Gets a single project with items preloaded within a workspace.

  Returns `{:ok, project}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_project_with_items(id, workspace_id)
      {:ok, %Project{project_items: [...]}}

      iex> get_project_with_items(456, workspace_id)
      {:error, :not_found}

  """
  def get_project_with_items(id, workspace_id) do
    case Project
         |> where([p], p.workspace_id == ^workspace_id)
         |> preload([:project_items, :created_by])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      project -> {:ok, project}
    end
  end

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  # Project Members

  @doc """
  Checks if a user is a member of a project.
  """
  def is_member?(project_id, user_id) do
    ProjectMember
    |> where([pm], pm.project_id == ^project_id and pm.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Returns the list of project IDs a user is a member of.
  """
  def get_user_project_ids(user_id) do
    ProjectMember
    |> where([pm], pm.user_id == ^user_id)
    |> select([pm], pm.project_id)
    |> Repo.all()
  end

  @doc """
  Adds a user as a member to a project.
  """
  def add_member(project_id, user_id) do
    %ProjectMember{}
    |> ProjectMember.changeset(%{project_id: project_id, user_id: user_id})
    |> Repo.insert()
  end

  @doc """
  Removes a user from a project.
  """
  def remove_member(project_id, user_id) do
    case Repo.get_by(ProjectMember, project_id: project_id, user_id: user_id) do
      nil -> {:error, :not_found}
      member -> Repo.delete(member)
    end
  end

  @doc """
  Lists all members of a project.
  """
  def list_members(project_id) do
    ProjectMember
    |> where([pm], pm.project_id == ^project_id)
    |> preload(:user)
    |> Repo.all()
  end

  # Project Items

  @doc """
  Adds an item to a project.

  ## Examples

      iex> add_item(project_id, "list", list_id)
      {:ok, %ProjectItem{}}

  """
  def add_item(project_id, item_type, item_id) do
    %ProjectItem{}
    |> ProjectItem.changeset(%{project_id: project_id, item_type: item_type, item_id: item_id})
    |> Repo.insert()
  end

  @doc """
  Removes an item from a project.

  ## Examples

      iex> remove_item("list", list_id)
      {:ok, %ProjectItem{}}

  """
  def remove_item(item_type, item_id) do
    case Repo.get_by(ProjectItem, item_type: item_type, item_id: item_id) do
      nil -> {:error, :not_found}
      item -> Repo.delete(item)
    end
  end

  @doc """
  Gets the project ID for an item, if it belongs to one.

  ## Examples

      iex> get_item_project_id("list", list_id)
      "project-uuid"

      iex> get_item_project_id("list", orphan_list_id)
      nil

  """
  def get_item_project_id(item_type, item_id) do
    # Normalize "board" to "list" for database lookup (API uses "board", DB uses "list")
    db_item_type = if item_type == "board", do: "list", else: item_type

    ProjectItem
    |> where([pi], pi.item_type == ^db_item_type and pi.item_id == ^item_id)
    |> select([pi], pi.project_id)
    |> Repo.one()
  end

  @doc """
  Lists all items for a project.

  ## Examples

      iex> list_items(project_id)
      [%ProjectItem{}, ...]

  """
  def list_items(project_id) do
    ProjectItem
    |> where([pi], pi.project_id == ^project_id)
    |> order_by([pi], asc: pi.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets all item IDs for a specific type that belong to any project.
  Useful for filtering out project items from workspace-level views.

  ## Examples

      iex> get_all_project_item_ids("list")
      ["uuid1", "uuid2", ...]

  """
  def get_all_project_item_ids(item_type) do
    ProjectItem
    |> where([pi], pi.item_type == ^item_type)
    |> select([pi], pi.item_id)
    |> Repo.all()
  end

  @doc """
  Removes all project memberships for a user.
  Used when soft-deleting a user.
  """
  def remove_all_memberships_for_user(user_id) do
    ProjectMember
    |> where([pm], pm.user_id == ^user_id)
    |> Repo.delete_all()
  end

  # Item Members

  alias Bridge.Projects.ItemMember

  @doc """
  Checks if a user is an item member.
  """
  def is_item_member?(item_type, item_id, user_id) do
    ItemMember
    |> where([im], im.item_type == ^item_type and im.item_id == ^item_id and im.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Returns item IDs the user has membership on, for a given type.
  """
  def get_user_item_member_ids(user_id, item_type) do
    ItemMember
    |> where([im], im.user_id == ^user_id and im.item_type == ^item_type)
    |> select([im], im.item_id)
    |> Repo.all()
  end

  @doc """
  Adds a user as a member to a specific item.
  """
  def add_item_member(attrs) do
    %ItemMember{}
    |> ItemMember.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a user from a specific item.
  """
  def remove_item_member(item_type, item_id, user_id) do
    case Repo.get_by(ItemMember, item_type: item_type, item_id: item_id, user_id: user_id) do
      nil -> {:error, :not_found}
      member -> Repo.delete(member)
    end
  end

  @doc """
  Lists all members of a specific item.
  """
  def list_item_members(item_type, item_id) do
    ItemMember
    |> where([im], im.item_type == ^item_type and im.item_id == ^item_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Removes all item memberships for a user.
  Used when soft-deleting a user.
  """
  def remove_all_item_memberships_for_user(user_id) do
    ItemMember
    |> where([im], im.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Gets the count of total memberships (projects + items) for a user.
  Used for guest limit enforcement.
  """
  def guest_membership_count(user_id) do
    project_count =
      ProjectMember
      |> where([pm], pm.user_id == ^user_id)
      |> Repo.aggregate(:count, :id)

    item_count =
      ItemMember
      |> where([im], im.user_id == ^user_id)
      |> Repo.aggregate(:count, :id)

    project_count + item_count
  end

  @doc """
  Returns item IDs of a given type that belong to projects the user is a member of.
  """
  def get_project_item_ids_for_user_projects(user_id, item_type) do
    from(pi in ProjectItem,
      join: pm in ProjectMember,
      on: pm.project_id == pi.project_id,
      where: pm.user_id == ^user_id and pi.item_type == ^item_type,
      select: pi.item_id
    )
    |> Repo.all()
  end
end
