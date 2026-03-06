defmodule Bridge.ApiKeys do
  @moduledoc """
  Context for user-scoped API keys.
  """

  import Ecto.Query, warn: false

  alias Bridge.Accounts
  alias Bridge.Accounts.User
  alias Bridge.ApiKeys.ApiKey
  alias Bridge.Authorization.Scopes
  alias Bridge.Repo

  @api_key_prefix "brk_"

  @doc """
  Returns all API keys for a user.
  """
  def list_user_api_keys(user_id) when is_binary(user_id) do
    ApiKey
    |> where([k], k.user_id == ^user_id and is_nil(k.revoked_at))
    |> order_by([k], desc: k.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a new API key for a user.

  Returns `{:ok, %{api_key: api_key, plaintext_key: key}}`.
  """
  def create_api_key_for_user(%User{} = user, attrs) when is_map(attrs) do
    requested_scopes = Map.get(attrs, "scopes") || Map.get(attrs, :scopes)

    with {:ok, scopes} <- resolve_scopes(user.role, requested_scopes),
         plaintext_key <- generate_plaintext_key(),
         key_hash <- hash_key(plaintext_key),
         key_prefix <- key_prefix(plaintext_key),
         {:ok, api_key} <- insert_api_key(user.id, attrs, scopes, key_hash, key_prefix) do
      {:ok, %{api_key: api_key, plaintext_key: plaintext_key}}
    end
  end

  @doc """
  Authenticates an API key and returns user + effective scopes.
  """
  def authenticate_api_key(plaintext_key) when is_binary(plaintext_key) do
    with true <- api_key_format?(plaintext_key),
         %ApiKey{} = api_key <- get_active_api_key_by_hash(hash_key(plaintext_key)),
         {:ok, user} <- Accounts.get_user(api_key.user_id) do
      effective_scopes = Scopes.intersect_with_role(api_key.scopes, user.role)

      {:ok,
       %{
         api_key: api_key,
         user: user,
         scopes: effective_scopes
       }}
    else
      _ -> {:error, :invalid_api_key}
    end
  end

  def authenticate_api_key(_), do: {:error, :invalid_api_key}

  @doc """
  Revokes an API key owned by a user.
  """
  def revoke_api_key_for_user(user_id, key_id) when is_binary(user_id) and is_binary(key_id) do
    query =
      from(k in ApiKey,
        where: k.id == ^key_id and k.user_id == ^user_id and is_nil(k.revoked_at)
      )

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      api_key ->
        api_key
        |> ApiKey.revoke_changeset()
        |> Repo.update()
    end
  end

  @doc """
  Updates `last_used_at` for a key.
  """
  def touch_last_used(%ApiKey{} = api_key) do
    api_key
    |> ApiKey.touch_last_used_changeset()
    |> Repo.update()
  end

  @doc """
  Intersects all active API key scopes for a user with role scopes.
  """
  def reconcile_scopes_for_user_role(user_id, role) when is_binary(user_id) and is_binary(role) do
    user_id
    |> active_keys_query()
    |> Repo.all()
    |> Enum.reduce_while({:ok, 0}, fn api_key, {:ok, count} ->
      adjusted_scopes = Scopes.intersect_with_role(api_key.scopes, role)

      if adjusted_scopes == api_key.scopes do
        {:cont, {:ok, count}}
      else
        case api_key |> ApiKey.scopes_changeset(%{scopes: adjusted_scopes}) |> Repo.update() do
          {:ok, _updated_api_key} -> {:cont, {:ok, count + 1}}
          {:error, changeset} -> {:halt, {:error, changeset}}
        end
      end
    end)
  end

  @doc """
  Deletes all API keys for a user.
  """
  def delete_all_for_user(user_id) when is_binary(user_id) do
    {count, _} =
      ApiKey
      |> where([k], k.user_id == ^user_id)
      |> Repo.delete_all()

    {:ok, count}
  end

  def api_key_prefix, do: @api_key_prefix

  def api_key_format?(value) when is_binary(value) do
    String.starts_with?(value, @api_key_prefix)
  end

  def api_key_format?(_), do: false

  defp resolve_scopes(role, nil), do: {:ok, Scopes.role_scopes(role)}

  defp resolve_scopes(role, requested_scopes) do
    if Scopes.valid_role_scopes?(requested_scopes, role) do
      {:ok, Scopes.normalize_scope_list(requested_scopes)}
    else
      {:error, :invalid_scopes}
    end
  end

  defp insert_api_key(user_id, attrs, scopes, key_hash, key_prefix) do
    name = Map.get(attrs, "name") || Map.get(attrs, :name)

    %ApiKey{}
    |> ApiKey.create_changeset(%{
      name: name,
      key_hash: key_hash,
      key_prefix: key_prefix,
      scopes: scopes,
      user_id: user_id
    })
    |> Repo.insert()
  end

  defp get_active_api_key_by_hash(key_hash) do
    ApiKey
    |> where([k], k.key_hash == ^key_hash and is_nil(k.revoked_at))
    |> Repo.one()
  end

  defp active_keys_query(user_id) do
    from(k in ApiKey, where: k.user_id == ^user_id and is_nil(k.revoked_at))
  end

  defp generate_plaintext_key do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    @api_key_prefix <> token
  end

  defp hash_key(plaintext_key) do
    :crypto.hash(:sha256, plaintext_key)
    |> Base.encode16(case: :lower)
  end

  defp key_prefix(plaintext_key) do
    String.slice(plaintext_key, 0, 12)
  end
end
