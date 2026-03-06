defmodule MissionspaceWeb.ApiKeyController do
  use MissionspaceWeb, :controller

  alias Missionspace.ApiKeys
  alias Missionspace.Authorization.Scopes

  action_fallback(MissionspaceWeb.FallbackController)

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    api_keys = ApiKeys.list_user_api_keys(current_user.id)
    render(conn, :index, api_keys: api_keys)
  end

  def scopes(conn, _params) do
    current_user = conn.assigns.current_user
    json(conn, %{data: %{scopes: Scopes.role_scopes(current_user.role)}})
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    case ApiKeys.create_api_key_for_user(current_user, params) do
      {:ok, %{api_key: api_key, plaintext_key: plaintext_key}} ->
        conn
        |> put_status(:created)
        |> render(:show, api_key: api_key, plaintext_key: plaintext_key)

      {:error, :invalid_scopes} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{scopes: ["contains invalid or unauthorized scopes"]}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => key_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _api_key} <- ApiKeys.revoke_api_key_for_user(current_user.id, key_id) do
      send_resp(conn, :no_content, "")
    end
  end

  def verify(conn, _params) do
    case {conn.assigns[:auth_method], conn.assigns[:current_api_key]} do
      {:api_key, api_key} when not is_nil(api_key) ->
        render(conn, :verify,
          api_key: api_key,
          user: conn.assigns.current_user,
          scopes: conn.assigns.current_user.scopes
        )

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "API key required"})
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
