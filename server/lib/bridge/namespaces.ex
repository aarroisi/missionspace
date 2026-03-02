defmodule Bridge.Namespaces do
  @moduledoc """
  The Namespaces context. Manages shared prefix namespace across boards and doc folders.
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo

  alias Bridge.Namespaces.Prefix

  @doc """
  Reserve a prefix for an entity (board or doc folder).
  """
  def reserve_prefix(prefix, entity_type, entity_id, workspace_id) do
    %Prefix{}
    |> Prefix.changeset(%{
      prefix: prefix,
      entity_type: entity_type,
      entity_id: entity_id,
      workspace_id: workspace_id
    })
    |> Repo.insert()
  end

  @doc """
  Release a prefix when an entity is deleted.
  """
  def release_prefix(entity_type, entity_id) do
    from(p in Prefix, where: p.entity_type == ^entity_type and p.entity_id == ^entity_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Check if a prefix is available in a workspace.
  """
  def check_prefix_available?(prefix, workspace_id) do
    not Repo.exists?(
      from(p in Prefix, where: p.workspace_id == ^workspace_id and p.prefix == ^prefix)
    )
  end

  @doc """
  Suggest a prefix based on a name, ensuring it's available in the workspace.
  """
  def suggest_prefix(name, workspace_id) do
    base =
      name
      |> String.replace(~r/[^a-zA-Z\s]/, "")
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&String.first/1)
      |> Enum.join()
      |> String.upcase()

    base =
      cond do
        String.length(base) >= 2 -> String.slice(base, 0, 5)
        String.length(base) == 1 -> base <> String.upcase(String.slice(name, 1, 1) || "X")
        true -> "XX"
      end

    find_available_prefix(base, workspace_id)
  end

  defp find_available_prefix(base, workspace_id) do
    max_len = min(5, String.length(base))

    result =
      Enum.find_value(2..max_len//1, fn len ->
        candidate = String.slice(base, 0, len)
        if check_prefix_available?(candidate, workspace_id), do: candidate
      end)

    result || add_numeric_suffix(String.slice(base, 0, 2), workspace_id)
  end

  defp add_numeric_suffix(base, workspace_id) do
    Enum.find_value(2..999, fn n ->
      candidate = "#{base}#{n}"

      if String.length(candidate) <= 5 && check_prefix_available?(candidate, workspace_id),
        do: candidate
    end) || base <> "X"
  end
end
