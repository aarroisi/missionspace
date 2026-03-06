defmodule BridgeWeb.Plugs.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  alias Bridge.Accounts
  alias Bridge.ApiKeys
  alias Bridge.Authorization.Scopes

  @resend_verification_path "/api/auth/resend-verification"

  def init(opts), do: opts

  def call(conn, _opts) do
    case extract_api_key(conn) do
      nil -> authenticate_with_session(conn)
      plaintext_key -> authenticate_with_api_key(conn, plaintext_key)
    end
  end

  defp authenticate_with_session(conn) do
    case get_session(conn, :user_id) do
      nil ->
        unauthorized(conn)

      user_id ->
        case Accounts.get_user(user_id) do
          {:ok, user} ->
            validate_authenticated_user(conn, user, :session, nil)

          {:error, :not_found} ->
            unauthorized(conn)
        end
    end
  end

  defp authenticate_with_api_key(conn, plaintext_key) do
    case ApiKeys.authenticate_api_key(plaintext_key) do
      {:ok, %{api_key: api_key, user: user, scopes: scopes}} ->
        _ = ApiKeys.touch_last_used(api_key)
        validate_authenticated_user(conn, user, :api_key, %{api_key: api_key, scopes: scopes})

      {:error, :invalid_api_key} ->
        unauthorized(conn)
    end
  end

  defp validate_authenticated_user(conn, user, auth_method, api_key_auth) do
    cond do
      not user.is_active ->
        conn
        |> maybe_clear_session(auth_method)
        |> put_status(:unauthorized)
        |> put_view(json: BridgeWeb.ErrorJSON)
        |> json(%{error: "Account has been deactivated"})
        |> halt()

      is_nil(user.email_verified_at) and conn.request_path != @resend_verification_path ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "email_not_verified"})
        |> halt()

      is_nil(user.workspace_id) ->
        conn
        |> put_status(:forbidden)
        |> put_view(json: BridgeWeb.ErrorJSON)
        |> json(%{error: "User not associated with any workspace"})
        |> halt()

      true ->
        user = assign_scopes(user, api_key_auth)

        conn
        |> assign(:current_user, user)
        |> assign(:current_user_id, user.id)
        |> assign(:workspace_id, user.workspace_id)
        |> assign(:auth_method, auth_method)
        |> maybe_assign_api_key(api_key_auth)
    end
  end

  defp assign_scopes(user, nil) do
    %{user | scopes: Scopes.role_scopes(user.role)}
  end

  defp assign_scopes(user, %{scopes: scopes}) do
    %{user | scopes: scopes}
  end

  defp maybe_assign_api_key(conn, nil), do: conn

  defp maybe_assign_api_key(conn, %{api_key: api_key}) do
    assign(conn, :current_api_key, api_key)
  end

  defp maybe_clear_session(conn, :session), do: clear_session(conn)
  defp maybe_clear_session(conn, _), do: conn

  defp extract_api_key(conn) do
    with nil <- List.first(get_req_header(conn, "x-api-key")),
         nil <- extract_bearer_api_key(conn) do
      nil
    else
      api_key when is_binary(api_key) -> api_key
    end
  end

  defp extract_bearer_api_key(conn) do
    case get_req_header(conn, "authorization") do
      [header | _] ->
        case String.split(header, ~r/\s+/, parts: 2) do
          [scheme, token] when is_binary(token) ->
            if String.downcase(scheme) == "bearer" and
                 String.starts_with?(token, ApiKeys.api_key_prefix()) do
              token
            else
              nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: BridgeWeb.ErrorJSON)
    |> render(:"401")
    |> halt()
  end
end
