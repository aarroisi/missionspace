defmodule BridgeWeb.ApiKeyJSON do
  alias Bridge.Accounts.User
  alias Bridge.ApiKeys.ApiKey

  def index(%{api_keys: api_keys}) do
    %{data: Enum.map(api_keys, &api_key_data/1)}
  end

  def show(%{api_key: api_key, plaintext_key: plaintext_key}) do
    %{
      data:
        api_key_data(api_key)
        |> Map.put(:key, plaintext_key)
        |> Map.put(:verify_endpoint, "/api/api-keys/verify")
    }
  end

  def verify(%{api_key: api_key, user: user, scopes: scopes}) do
    %{
      data: %{
        valid: true,
        auth_method: "api_key",
        api_key: api_key_data(api_key),
        user: verify_user_data(user),
        scopes: scopes
      }
    }
  end

  defp api_key_data(%ApiKey{} = api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      key_prefix: api_key.key_prefix,
      scopes: api_key.scopes,
      last_used_at: api_key.last_used_at,
      revoked_at: api_key.revoked_at,
      inserted_at: api_key.inserted_at,
      updated_at: api_key.updated_at
    }
  end

  defp verify_user_data(%User{} = user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      workspace_id: user.workspace_id
    }
  end
end
