defmodule MissionspaceWeb.ProjectItemJSON do
  alias Missionspace.Projects.ProjectItem

  def index(%{items: items}) do
    %{data: for(item <- items, do: data(item))}
  end

  def show(%{item: item}) do
    %{data: data(item)}
  end

  defp data(%ProjectItem{} = item) do
    %{
      id: item.id,
      project_id: item.project_id,
      # API uses "board", DB stores "list"
      item_type: normalize_item_type(item.item_type),
      item_id: item.item_id,
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  defp normalize_item_type("list"), do: "board"
  defp normalize_item_type(other), do: other
end
