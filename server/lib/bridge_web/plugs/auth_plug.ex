defmodule BridgeWeb.Plugs.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  alias Bridge.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      case Accounts.get_user(user_id) do
        {:ok, user} ->
          cond do
            # Check if user is inactive (soft-deleted)
            not user.is_active ->
              conn
              |> clear_session()
              |> put_status(:unauthorized)
              |> put_view(json: BridgeWeb.ErrorJSON)
              |> json(%{error: "Account has been deactivated"})
              |> halt()

            # Check if email is verified (allow resend-verification endpoint)
            is_nil(user.email_verified_at) and
                conn.request_path != "/api/auth/resend-verification" ->
              conn
              |> put_status(:forbidden)
              |> json(%{error: "email_not_verified"})
              |> halt()

            # Check if user has a workspace
            is_nil(user.workspace_id) ->
              conn
              |> put_status(:forbidden)
              |> put_view(json: BridgeWeb.ErrorJSON)
              |> json(%{error: "User not associated with any workspace"})
              |> halt()

            # User is valid
            true ->
              conn
              |> assign(:current_user, user)
              |> assign(:current_user_id, user.id)
              |> assign(:workspace_id, user.workspace_id)
          end

        {:error, :not_found} ->
          conn
          |> put_status(:unauthorized)
          |> put_view(json: BridgeWeb.ErrorJSON)
          |> render(:"401")
          |> halt()
      end
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(json: BridgeWeb.ErrorJSON)
      |> render(:"401")
      |> halt()
    end
  end
end
