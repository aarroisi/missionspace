defmodule Bridge.Docs do
  @moduledoc """
  The Docs context.
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo

  alias Bridge.Docs.{Doc, DocFolder}

  # ============================================================================
  # Doc Folder functions
  # ============================================================================

  def list_doc_folders(workspace_id, user, opts \\ []) do
    DocFolder
    |> where([f], f.workspace_id == ^workspace_id)
    |> filter_accessible_folders(user)
    |> order_by([f], desc: f.id)
    |> preload([:created_by])
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  def list_starred_doc_folders(workspace_id, user, opts \\ []) do
    starred_ids = Bridge.Stars.starred_ids(user.id, "doc_folder")

    if MapSet.size(starred_ids) == 0 do
      %{entries: [], metadata: %{after: nil, before: nil, limit: 50}}
    else
      ids = MapSet.to_list(starred_ids)

      DocFolder
      |> where([f], f.id in ^ids and f.workspace_id == ^workspace_id)
      |> filter_accessible_folders(user)
      |> order_by([f], desc: f.id)
      |> preload([:created_by])
      |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
    end
  end

  defp filter_accessible_folders(query, %{role: "owner", id: user_id}) do
    where(query, [f], f.visibility == "shared" or f.created_by_id == ^user_id)
  end

  defp filter_accessible_folders(query, %{id: user_id}) do
    project_folder_ids =
      Bridge.Projects.get_project_item_ids_for_user_projects(user_id, "doc_folder")

    item_member_ids = Bridge.Projects.get_user_item_member_ids(user_id, "doc_folder")

    where(
      query,
      [f],
      f.id in ^project_folder_ids or
        f.created_by_id == ^user_id or
        (f.visibility == "shared" and f.id in ^item_member_ids)
    )
  end

  def get_doc_folder(id, workspace_id) do
    case DocFolder
         |> where([f], f.workspace_id == ^workspace_id)
         |> preload([:created_by])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      folder -> {:ok, folder}
    end
  end

  def create_doc_folder(attrs \\ %{}) do
    Repo.transaction(fn ->
      with {:ok, folder} <-
             %DocFolder{}
             |> DocFolder.create_changeset(attrs)
             |> Repo.insert(),
           {:ok, _prefix} <-
             Bridge.Namespaces.reserve_prefix(
               folder.prefix,
               "doc_folder",
               folder.id,
               folder.workspace_id
             ) do
        folder |> Repo.preload(:created_by)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def update_doc_folder(%DocFolder{} = folder, attrs) do
    folder
    |> DocFolder.changeset(attrs)
    |> Repo.update()
  end

  def delete_doc_folder(%DocFolder{} = folder) do
    result = Repo.delete(folder)

    case result do
      {:ok, _} -> Bridge.Namespaces.release_prefix("doc_folder", folder.id)
      _ -> nil
    end

    result
  end


  # ============================================================================
  # Doc functions
  # ============================================================================

  def list_docs(workspace_id, _user, opts \\ []) do
    doc_folder_id = Keyword.get(opts, :doc_folder_id)

    query =
      Doc
      |> where([d], d.workspace_id == ^workspace_id)
      |> order_by([d], desc: d.id)
      |> preload([:author, :doc_folder])

    query =
      if doc_folder_id do
        where(query, [d], d.doc_folder_id == ^doc_folder_id)
      else
        query
      end

    query
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  def list_docs_by_author(author_id, opts \\ []) do
    Doc
    |> where([d], d.author_id == ^author_id)
    |> order_by([d], desc: d.id)
    |> preload([:author, :doc_folder])
    |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
  end

  def list_starred_docs(workspace_id, user_id, opts \\ []) do
    starred_ids = Bridge.Stars.starred_ids(user_id, "doc")

    if MapSet.size(starred_ids) == 0 do
      %{entries: [], metadata: %{after: nil, before: nil, limit: 50}}
    else
      ids = MapSet.to_list(starred_ids)

      Doc
      |> where([d], d.id in ^ids and d.workspace_id == ^workspace_id)
      |> order_by([d], desc: d.id)
      |> preload([:author, :doc_folder])
      |> Repo.paginate(Keyword.merge([cursor_fields: [:id], limit: 50], opts))
    end
  end

  def get_doc(id, workspace_id) do
    case Doc
         |> where([d], d.workspace_id == ^workspace_id)
         |> preload([:author, :doc_folder])
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      doc -> {:ok, doc}
    end
  end

  def create_doc(attrs \\ %{}) do
    doc_folder_id = attrs["doc_folder_id"] || attrs[:doc_folder_id]

    # Atomically increment the folder's sequence counter
    seq_num =
      if is_binary(doc_folder_id) do
        {1, [%{doc_sequence_counter: counter}]} =
          from(f in DocFolder,
            where: f.id == ^doc_folder_id,
            select: %{doc_sequence_counter: f.doc_sequence_counter}
          )
          |> Repo.update_all(inc: [doc_sequence_counter: 1])

        counter
      else
        0
      end

    attrs_with_seq = Map.put(attrs, "sequence_number", seq_num)

    case %Doc{}
         |> Doc.changeset(attrs_with_seq)
         |> Repo.insert() do
      {:ok, doc} -> {:ok, Repo.preload(doc, [:author, :doc_folder])}
      error -> error
    end
  end

  def update_doc(%Doc{} = doc, attrs) do
    doc
    |> Doc.changeset(attrs)
    |> Repo.update()
  end

  def delete_doc(%Doc{} = doc) do
    Repo.delete(doc)
  end

  def change_doc(%Doc{} = doc, attrs \\ %{}) do
    Doc.changeset(doc, attrs)
  end


  def update_doc_content(%Doc{} = doc, content) when is_binary(content) do
    update_doc(doc, %{content: content})
  end
end
