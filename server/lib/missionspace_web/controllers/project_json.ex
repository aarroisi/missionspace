defmodule MissionspaceWeb.ProjectJSON do
  alias Missionspace.Projects.Project

  @doc """
  Renders a list of projects.
  """
  def index(%{page: page}) do
    %{
      data: for(project <- page.entries, do: data(project)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def index(%{projects: projects}) do
    %{data: for(project <- projects, do: data(project))}
  end

  @doc """
  Renders a single project.
  """
  def show(%{project: project}) do
    %{data: data(project)}
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%Project{} = project) do
    base = %{
      id: project.id,
      name: project.name,
      description: project.description,
      starred: project.starred,
      start_date: project.start_date,
      end_date: project.end_date,
      inserted_at: project.inserted_at,
      updated_at: project.updated_at
    }

    # Include created_by if preloaded
    base =
      if Ecto.assoc_loaded?(project.created_by) do
        Map.put(base, :created_by, user_data(project.created_by))
      else
        base
      end

    # Include items if preloaded
    if Ecto.assoc_loaded?(project.project_items) do
      Map.put(base, :items, Enum.map(project.project_items, &item_data/1))
    else
      base
    end
  end

  defp user_data(nil), do: nil

  defp user_data(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      avatar: user.avatar
    }
  end

  defp item_data(item) do
    %{
      id: item.id,
      # API uses "board", DB stores "list"
      item_type: normalize_item_type(item.item_type),
      item_id: item.item_id
    }
  end

  defp normalize_item_type("list"), do: "board"
  defp normalize_item_type(other), do: other

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
