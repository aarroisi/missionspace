defmodule MissionspaceWeb.DocFolderJSON do
  alias Missionspace.Docs.DocFolder

  def index(%{page: page}) do
    %{
      data: for(folder <- page.entries, do: data(folder)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def show(%{doc_folder: folder}) do
    %{data: data(folder)}
  end

  defp data(%DocFolder{} = folder) do
    %{
      id: folder.id,
      name: folder.name,
      prefix: folder.prefix,
      visibility: folder.visibility,
      starred: folder.starred,
      created_by_id: folder.created_by_id,
      created_by: get_created_by(folder),
      inserted_at: folder.inserted_at,
      updated_at: folder.updated_at
    }
  end

  defp get_created_by(%DocFolder{created_by: %{id: id, name: name, email: email, avatar: avatar}}),
    do: %{id: id, name: name, email: email, avatar: avatar}

  defp get_created_by(_), do: nil
end
