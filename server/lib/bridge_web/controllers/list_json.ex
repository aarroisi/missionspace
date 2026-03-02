defmodule BridgeWeb.ListJSON do
  alias Bridge.Lists.List

  @doc """
  Renders a list of lists.
  """
  def index(%{page: page}) do
    %{
      data: for(list <- page.entries, do: data(list)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def index(%{lists: lists}) do
    %{data: for(list <- lists, do: data(list))}
  end

  @doc """
  Renders a single list.
  """
  def show(%{list: list}) do
    %{data: data(list)}
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%List{} = list) do
    base = %{
      id: list.id,
      name: list.name,
      prefix: list.prefix,
      visibility: list.visibility,
      starred: list.starred,
      created_by_id: list.created_by_id,
      created_by: get_created_by(list),
      inserted_at: list.inserted_at,
      updated_at: list.updated_at
    }

    # Include statuses if loaded
    if Ecto.assoc_loaded?(list.statuses) do
      Map.put(base, :statuses, Enum.map(list.statuses, &status_data/1))
    else
      base
    end
  end

  defp get_created_by(%List{created_by: %{id: id, name: name, email: email}}),
    do: %{id: id, name: name, email: email}

  defp get_created_by(_), do: nil

  defp status_data(status) do
    %{
      id: status.id,
      name: status.name,
      color: status.color,
      position: status.position,
      is_done: status.is_done
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
