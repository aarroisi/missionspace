defmodule Bridge.Search do
  @moduledoc """
  Workspace-scoped search across all entity types.
  Uses ILIKE for simple pattern matching with concurrent queries.
  """

  import Ecto.Query, warn: false

  alias Bridge.Repo
  alias Bridge.Accounts.User
  alias Bridge.Authorization
  alias Bridge.Projects
  alias Bridge.Projects.Project
  alias Bridge.Lists.List
  alias Bridge.Docs.{Doc, DocFolder}
  alias Bridge.Chat.Channel

  @max_per_category 5

  @doc """
  Searches across all entity types within a workspace.
  Returns a map of categorized results, respecting access control.
  """
  def search(query, workspace_id, user) when is_binary(query) do
    query = String.trim(query)

    if query == "" do
      empty_results()
    else
      pattern = "%#{sanitize_like(query)}%"
      do_search(pattern, workspace_id, user)
    end
  end

  defp empty_results do
    %{
      projects: [],
      boards: [],
      tasks: [],
      doc_folders: [],
      docs: [],
      channels: [],
      members: []
    }
  end

  defp sanitize_like(query) do
    query
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp do_search(pattern, workspace_id, user) do
    tasks = %{
      projects: Task.async(fn -> search_projects(pattern, workspace_id, user) end),
      boards: Task.async(fn -> search_boards(pattern, workspace_id, user) end),
      tasks: Task.async(fn -> search_tasks(pattern, workspace_id, user) end),
      doc_folders: Task.async(fn -> search_doc_folders(pattern, workspace_id, user) end),
      docs: Task.async(fn -> search_docs(pattern, workspace_id, user) end),
      channels: Task.async(fn -> search_channels(pattern, workspace_id, user) end),
      members: Task.async(fn -> search_members(pattern, workspace_id) end)
    }

    Map.new(tasks, fn {key, task} -> {key, Task.await(task, 5000)} end)
  end

  # Projects: search name, description
  defp search_projects(pattern, workspace_id, user) do
    Project
    |> where([p], p.workspace_id == ^workspace_id)
    |> where([p], ilike(p.name, ^pattern) or ilike(coalesce(p.description, ""), ^pattern))
    |> filter_projects(user)
    |> limit(@max_per_category)
    |> order_by([p], desc: p.id)
    |> Repo.all()
  end

  defp filter_projects(query, user) do
    case Authorization.accessible_project_ids(user) do
      :all -> query
      project_ids -> where(query, [p], p.id in ^project_ids)
    end
  end

  # Boards (Lists): search name, prefix
  defp search_boards(pattern, workspace_id, user) do
    List
    |> where([l], l.workspace_id == ^workspace_id)
    |> where([l], ilike(l.name, ^pattern) or ilike(l.prefix, ^pattern))
    |> filter_accessible(user, "list")
    |> limit(@max_per_category)
    |> order_by([l], desc: l.id)
    |> Repo.all()
  end

  # Tasks: search title, key (prefix-seq), notes
  defp search_tasks(pattern, workspace_id, user) do
    List
    |> join(:inner, [l], t in Bridge.Lists.Task, on: t.list_id == l.id)
    |> where([l, t], l.workspace_id == ^workspace_id)
    |> where(
      [l, t],
      ilike(t.title, ^pattern) or
        ilike(fragment("? || '-' || ?::text", l.prefix, t.sequence_number), ^pattern)
    )
    |> filter_accessible(user, "list")
    |> limit(@max_per_category)
    |> order_by([l, t], desc: t.id)
    |> select([l, t], {t, l})
    |> Repo.all()
    |> Enum.map(fn {task, list} ->
      task
      |> Repo.preload([:assignee, :status])
      |> Map.put(:list, list)
    end)
  end

  # Doc Folders: search name, prefix
  defp search_doc_folders(pattern, workspace_id, user) do
    DocFolder
    |> where([f], f.workspace_id == ^workspace_id)
    |> where([f], ilike(f.name, ^pattern) or ilike(f.prefix, ^pattern))
    |> filter_accessible(user, "doc_folder")
    |> limit(@max_per_category)
    |> order_by([f], desc: f.id)
    |> Repo.all()
  end

  # Docs: search title, content
  defp search_docs(pattern, workspace_id, user) do
    DocFolder
    |> join(:inner, [f], d in Doc, on: d.doc_folder_id == f.id)
    |> where([f, d], d.workspace_id == ^workspace_id)
    |> where([f, d], ilike(d.title, ^pattern) or ilike(coalesce(d.content, ""), ^pattern))
    |> filter_accessible(user, "doc_folder")
    |> limit(@max_per_category)
    |> order_by([f, d], desc: d.id)
    |> select([f, d], {d, f})
    |> Repo.all()
    |> Enum.map(fn {doc, folder} -> Map.put(doc, :doc_folder, folder) end)
  end

  # Channels: search name
  defp search_channels(pattern, workspace_id, user) do
    Channel
    |> where([c], c.workspace_id == ^workspace_id)
    |> where([c], ilike(c.name, ^pattern))
    |> filter_accessible(user, "channel")
    |> limit(@max_per_category)
    |> order_by([c], desc: c.id)
    |> Repo.all()
  end

  # Members: search name, email
  defp search_members(pattern, workspace_id) do
    User
    |> where([u], u.workspace_id == ^workspace_id and u.is_active == true)
    |> where([u], ilike(u.name, ^pattern) or ilike(u.email, ^pattern))
    |> limit(@max_per_category)
    |> order_by([u], desc: u.inserted_at)
    |> Repo.all()
  end

  # Shared access control filter for items with visibility
  # Owner: sees all shared + own private
  defp filter_accessible(query, %User{role: "owner", id: user_id}, _item_type) do
    where(query, [q], q.visibility == "shared" or q.created_by_id == ^user_id)
  end

  # Non-owner: sees project items + own + invited shared items
  defp filter_accessible(query, %User{id: user_id}, item_type) do
    project_item_ids = Projects.get_project_item_ids_for_user_projects(user_id, item_type)
    item_member_ids = Projects.get_user_item_member_ids(user_id, item_type)

    where(
      query,
      [q],
      q.id in ^project_item_ids or
        q.created_by_id == ^user_id or
        (q.visibility == "shared" and q.id in ^item_member_ids)
    )
  end
end
