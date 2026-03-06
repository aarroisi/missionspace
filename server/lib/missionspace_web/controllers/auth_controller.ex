defmodule MissionspaceWeb.AuthController do
  use MissionspaceWeb, :controller

  alias Missionspace.Accounts

  action_fallback(MissionspaceWeb.FallbackController)

  @device_cookie_name "ms_device"
  @device_cookie_max_age 1_209_600
  @device_cookie_opts [max_age: @device_cookie_max_age, same_site: "Lax", http_only: true]

  def register(conn, %{
        "workspace_name" => workspace_name,
        "name" => name,
        "email" => email,
        "password" => password
      }) do
    case Accounts.register_workspace_and_user(workspace_name, name, email, password) do
      {:ok, %{workspace: workspace, user: user}} ->
        with {:ok, conn, device_session} <- ensure_device_session_cookie(conn),
             {:ok, %{device_account: device_account, session_token: session_token}} <-
               Accounts.remember_device_account(device_session, user) do
          conn
          |> put_current_auth_session(user, device_account.id, session_token)
          |> put_status(:created)
          |> json(auth_payload(user, workspace))
        end

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        if is_nil(user.email_verified_at) do
          conn
          |> put_session(:user_id, user.id)
          |> put_session(:workspace_id, user.workspace_id)
          |> put_status(:forbidden)
          |> json(%{error: "email_not_verified"})
        else
          with {:ok, conn, device_session} <- ensure_device_session_cookie(conn),
               {:ok, %{device_account: device_account, session_token: session_token}} <-
                 Accounts.remember_device_account(device_session, user) do
            conn
            |> put_current_auth_session(user, device_account.id, session_token)
            |> json(auth_payload(user, user.workspace))
          end
        end

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def logout(conn, _params) do
    conn = fetch_cookies(conn)

    conn =
      with {:ok, device_session} <- fetch_device_session(conn),
           current_user_id when is_binary(current_user_id) <- get_session(conn, :user_id),
           {:ok, _device_account, _state} <-
             Accounts.sign_out_device_account(device_session, current_user_id) do
        clear_current_auth_session(conn)
      else
        _ -> clear_current_auth_session(conn)
      end

    json(conn, %{message: "Logged out successfully"})
  end

  def accounts(conn, _params) do
    conn = fetch_cookies(conn)

    {:ok, account_summaries} =
      Accounts.list_device_accounts(
        device_cookie_token(conn),
        get_session(conn, :current_device_account_id)
      )

    json(conn, %{data: Enum.map(account_summaries, &account_summary_payload/1)})
  end

  def switch_account(conn, %{"user_id" => user_id}) do
    conn = fetch_cookies(conn)

    with {:ok, device_session} <- fetch_device_session(conn),
         {:ok, %{device_account: device_account, session_token: session_token}} <-
           Accounts.switch_device_account(device_session, user_id) do
      conn
      |> put_current_auth_session(device_account.user, device_account.id, session_token)
      |> json(auth_payload(device_account.user, device_account.user.workspace))
    else
      {:error, :reauth_required} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "reauth_required"})

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "account_not_available"})
    end
  end

  def add_account(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        if is_nil(user.email_verified_at) do
          conn
          |> put_status(:forbidden)
          |> json(%{error: "email_not_verified"})
        else
          with {:ok, conn, device_session} <- ensure_device_session_cookie(conn),
               {:ok, %{device_account: device_account}} <-
                 Accounts.remember_device_account(device_session, user) do
            json(conn, %{
              data:
                account_summary_payload(
                  Accounts.device_account_summary(
                    device_account,
                    "available",
                    get_session(conn, :current_device_account_id)
                  )
                )
            })
          end
        end

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def sign_out_account(conn, %{"user_id" => user_id}) do
    conn = fetch_cookies(conn)

    with {:ok, device_session} <- fetch_device_session(conn),
         {:ok, device_account, state} <- Accounts.sign_out_device_account(device_session, user_id) do
      conn =
        if get_session(conn, :user_id) == user_id do
          clear_current_auth_session(conn)
        else
          conn
        end

      json(conn, %{
        data:
          account_summary_payload(
            Accounts.device_account_summary(
              device_account,
              state,
              get_session(conn, :current_device_account_id)
            )
          )
      })
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "account_not_available"})
    end
  end

  def reauth_account(conn, %{"user_id" => user_id, "password" => password}) do
    conn = fetch_cookies(conn)

    with {:ok, device_session} <- fetch_device_session(conn),
         {:ok, %{device_account: device_account, session_token: session_token}} <-
           Accounts.reauthenticate_device_account(device_session, user_id, password) do
      conn
      |> put_current_auth_session(device_account.user, device_account.id, session_token)
      |> json(auth_payload(device_account.user, device_account.user.workspace))
    else
      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})

      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "account_not_available"})
    end
  end

  def remove_account(conn, %{"user_id" => user_id}) do
    conn = fetch_cookies(conn)

    with {:ok, device_session} <- fetch_device_session(conn),
         {:ok, _device_account} <- Accounts.remove_device_account(device_session, user_id) do
      conn =
        if get_session(conn, :user_id) == user_id do
          clear_current_auth_session(conn)
        else
          conn
        end

      send_resp(conn, :no_content, "")
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "account_not_available"})
    end
  end

  def me(conn, _params) do
    conn = fetch_cookies(conn)

    case authenticate_current_session(conn) do
      {:ok, conn, user, _device_account_id, _session_token} ->
        json(conn, auth_payload(user, user.workspace))

      {:error, :email_not_verified, conn} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "email_not_verified"})

      {:error, :not_authenticated, conn} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end

  def update_me(conn, %{"user" => user_params}) do
    current_user = conn.assigns.current_user

    # Only allow updating name, email, avatar, and timezone
    allowed_params = Map.take(user_params, ["name", "email", "avatar", "timezone"])

    case Accounts.update_user(current_user, allowed_params) do
      {:ok, user} ->
        user = Missionspace.Repo.preload(user, :workspace)

        json(conn, auth_payload(user, user.workspace))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def verify_email(conn, %{"token" => token}) do
    case Accounts.verify_email(token) do
      {:ok, _user} ->
        json(conn, %{message: "Email verified successfully"})

      {:error, :invalid_token} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid or expired verification token"})
    end
  end

  def forgot_password(conn, %{"email" => email}) do
    Accounts.request_password_reset(email)
    # Always return success to prevent email enumeration
    json(conn, %{message: "If an account exists with that email, we sent a password reset link"})
  end

  def reset_password(conn, %{"token" => token, "password" => password}) do
    case Accounts.reset_password(token, password) do
      {:ok, _user} ->
        json(conn, %{message: "Password reset successfully"})

      {:error, :invalid_token} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid reset token"})

      {:error, :token_expired} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Reset token has expired"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def resend_verification(conn, _params) do
    current_user = conn.assigns.current_user

    if current_user.email_verified_at do
      json(conn, %{message: "Email already verified"})
    else
      case Accounts.resend_verification_email(current_user) do
        {:ok, _user} ->
          json(conn, %{message: "Verification email sent"})

        {:error, _} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to send verification email"})
      end
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp auth_payload(user, workspace) do
    %{
      user: user_payload(user),
      workspace: workspace_payload(workspace),
      token: Phoenix.Token.sign(MissionspaceWeb.Endpoint, "user socket", user.id)
    }
  end

  defp user_payload(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      avatar: user.avatar,
      timezone: user.timezone,
      role: user.role,
      workspace_id: user.workspace_id
    }
  end

  defp workspace_payload(workspace) do
    %{
      id: workspace.id,
      name: workspace.name,
      slug: workspace.slug,
      logo: workspace.logo
    }
  end

  defp account_summary_payload(summary) do
    %{
      user: user_payload(summary.user),
      workspace: workspace_payload(summary.workspace),
      current: summary.current,
      state: summary.state
    }
  end

  defp authenticate_current_session(conn) do
    case {
      device_cookie_token(conn),
      get_session(conn, :current_device_account_id),
      get_session(conn, :current_device_account_token)
    } do
      {device_token, device_account_id, session_token}
      when is_binary(device_token) and is_binary(device_account_id) and is_binary(session_token) ->
        case Accounts.authenticate_device_account_session(
               device_token,
               device_account_id,
               session_token
             ) do
          {:ok, device_account} ->
            user = device_account.user

            if is_nil(user.email_verified_at) do
              {:error, :email_not_verified, clear_current_auth_session(conn)}
            else
              {:ok, put_current_auth_session(conn, user, device_account.id, session_token), user,
               device_account.id, session_token}
            end

          _ ->
            {:error, :not_authenticated, clear_current_auth_session(conn)}
        end

      _ ->
        authenticate_legacy_session(conn)
    end
  end

  defp authenticate_legacy_session(conn) do
    case get_session(conn, :user_id) do
      nil ->
        {:error, :not_authenticated, clear_current_auth_session(conn)}

      user_id ->
        case Accounts.get_user(user_id) do
          {:ok, user} ->
            user = Missionspace.Repo.preload(user, :workspace)

            if is_nil(user.email_verified_at) do
              {:error, :email_not_verified, conn}
            else
              {:ok, conn, user, nil, nil}
            end

          {:error, :not_found} ->
            {:error, :not_authenticated, clear_current_auth_session(conn)}
        end
    end
  end

  defp ensure_device_session_cookie(conn) do
    with {:ok, %{device_session: device_session, token: device_token}} <-
           Accounts.ensure_device_session(device_cookie_token(conn)) do
      {:ok, put_resp_cookie(conn, @device_cookie_name, device_token, @device_cookie_opts),
       device_session}
    end
  end

  defp fetch_device_session(conn) do
    case Accounts.get_device_session(device_cookie_token(conn)) do
      {:ok, device_session} -> {:ok, device_session}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp put_current_auth_session(conn, user, device_account_id, session_token) do
    conn
    |> put_session(:user_id, user.id)
    |> put_session(:workspace_id, user.workspace_id)
    |> put_session(:current_device_account_id, device_account_id)
    |> put_session(:current_device_account_token, session_token)
  end

  defp clear_current_auth_session(conn) do
    conn
    |> delete_session(:user_id)
    |> delete_session(:workspace_id)
    |> delete_session(:current_device_account_id)
    |> delete_session(:current_device_account_token)
  end

  defp device_cookie_token(conn) do
    conn.req_cookies[@device_cookie_name]
  end
end
