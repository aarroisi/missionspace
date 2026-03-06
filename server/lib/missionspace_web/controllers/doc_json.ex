defmodule MissionspaceWeb.DocJSON do
  alias Missionspace.Docs.Doc

  @doc """
  Renders a list of docs.
  """
  def index(%{page: page}) do
    %{
      data: for(doc <- page.entries, do: data(doc)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def index(%{docs: docs}) do
    %{data: for(doc <- docs, do: data(doc))}
  end

  @doc """
  Renders a single doc.
  """
  def show(%{doc: doc}) do
    %{data: data(doc)}
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%Doc{} = doc) do
    %{
      id: doc.id,
      title: doc.title,
      content: doc.content,
      starred: doc.starred,
      doc_folder_id: doc.doc_folder_id,
      sequence_number: doc.sequence_number,
      key: get_key(doc),
      created_by: get_created_by(doc),
      inserted_at: DateTime.to_iso8601(doc.inserted_at),
      updated_at: DateTime.to_iso8601(doc.updated_at)
    }
  end

  defp get_key(%Doc{doc_folder: %{prefix: prefix}, sequence_number: seq})
       when is_binary(prefix) and is_integer(seq),
       do: "#{prefix}-#{seq}"

  defp get_key(_), do: nil

  defp get_created_by(%Doc{author: %{id: id, name: name, email: email, avatar: avatar}}),
    do: %{id: id, name: name, email: email, avatar: avatar}

  defp get_created_by(_), do: nil

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
