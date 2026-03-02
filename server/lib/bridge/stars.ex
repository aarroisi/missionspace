defmodule Bridge.Stars do
  @moduledoc """
  Context for per-user starring of entities.
  """

  import Ecto.Query
  alias Bridge.Repo
  alias Bridge.Stars.UserStar

  @doc """
  Toggles a star for a user on an entity. Returns {:ok, :starred} or {:ok, :unstarred}.
  """
  def toggle_star(user_id, starrable_type, starrable_id) do
    case Repo.get_by(UserStar,
           user_id: user_id,
           starrable_type: starrable_type,
           starrable_id: starrable_id
         ) do
      nil ->
        %UserStar{}
        |> UserStar.changeset(%{
          user_id: user_id,
          starrable_type: starrable_type,
          starrable_id: starrable_id
        })
        |> Repo.insert()
        |> case do
          {:ok, _} -> {:ok, :starred}
          error -> error
        end

      star ->
        case Repo.delete(star) do
          {:ok, _} -> {:ok, :unstarred}
          error -> error
        end
    end
  end

  @doc """
  Returns a MapSet of starred entity IDs for a user and type.
  """
  def starred_ids(user_id, starrable_type) do
    UserStar
    |> where([s], s.user_id == ^user_id and s.starrable_type == ^starrable_type)
    |> select([s], s.starrable_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Marks entities or a single entity with their starred status for a given user.
  Entities must have a virtual `starred` field.
  """
  def mark_starred(entities, user_id, starrable_type)

  def mark_starred(entities, user_id, starrable_type) when is_list(entities) do
    ids = starred_ids(user_id, starrable_type)
    Enum.map(entities, fn entity -> %{entity | starred: MapSet.member?(ids, entity.id)} end)
  end

  def mark_starred(%{id: id} = entity, user_id, starrable_type) do
    ids = starred_ids(user_id, starrable_type)
    %{entity | starred: MapSet.member?(ids, id)}
  end
end
