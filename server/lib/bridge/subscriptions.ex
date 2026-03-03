defmodule Bridge.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  Manages user subscriptions to items (tasks, docs, channels, threads).
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo
  alias Bridge.Subscriptions.Subscription

  @doc """
  Subscribes a user to an item. Idempotent — does nothing if already subscribed.

  ## Examples

      iex> subscribe(%{item_type: "task", item_id: id, user_id: uid, workspace_id: wid})
      {:ok, %Subscription{}}

  """
  def subscribe(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:item_type, :item_id, :user_id])
    |> case do
      {:ok, subscription} ->
        # on_conflict: :nothing returns id=nil when conflict, so re-fetch
        if subscription.id do
          {:ok, subscription}
        else
          case get_subscription(attrs.item_type, attrs.item_id, attrs.user_id) do
            {:ok, existing} -> {:ok, existing}
            _ -> {:ok, subscription}
          end
        end

      error ->
        error
    end
  end

  @doc """
  Unsubscribes a user from an item.

  ## Examples

      iex> unsubscribe("task", item_id, user_id)
      {:ok, %Subscription{}}

      iex> unsubscribe("task", item_id, user_id)
      {:error, :not_found}

  """
  def unsubscribe(item_type, item_id, user_id) do
    case get_subscription(item_type, item_id, user_id) do
      {:ok, subscription} -> Repo.delete(subscription)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Checks if a user is subscribed to an item.

  ## Examples

      iex> subscribed?("task", item_id, user_id)
      true

  """
  def subscribed?(item_type, item_id, user_id) do
    Subscription
    |> where([s], s.item_type == ^item_type and s.item_id == ^item_id and s.user_id == ^user_id)
    |> Repo.exists?()
  end

  @doc """
  Returns the list of subscriber user IDs for an item.

  ## Examples

      iex> list_subscriber_ids("task", item_id)
      ["user-id-1", "user-id-2"]

  """
  def list_subscriber_ids(item_type, item_id) do
    Subscription
    |> where([s], s.item_type == ^item_type and s.item_id == ^item_id)
    |> select([s], s.user_id)
    |> Repo.all()
  end

  @doc """
  Returns the list of subscriptions for an item with users preloaded.

  ## Examples

      iex> list_subscribers("task", item_id)
      [%Subscription{user: %User{}}, ...]

  """
  def list_subscribers(item_type, item_id) do
    Subscription
    |> where([s], s.item_type == ^item_type and s.item_id == ^item_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Deletes all subscriptions for a user. Used when soft-deleting a user.
  """
  def delete_all_for_user(user_id) do
    Subscription
    |> where([s], s.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Deletes all subscriptions for an item. Used when deleting an item.
  """
  def delete_all_for_item(item_type, item_id) do
    Subscription
    |> where([s], s.item_type == ^item_type and s.item_id == ^item_id)
    |> Repo.delete_all()
  end

  # Private

  defp get_subscription(item_type, item_id, user_id) do
    case Subscription
         |> where(
           [s],
           s.item_type == ^item_type and s.item_id == ^item_id and s.user_id == ^user_id
         )
         |> Repo.one() do
      nil -> {:error, :not_found}
      subscription -> {:ok, subscription}
    end
  end
end
