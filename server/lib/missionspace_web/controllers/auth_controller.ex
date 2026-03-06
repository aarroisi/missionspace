defmodule MissionspaceWeb.AuthController do
  use MissionspaceWeb, :controller

  alias Missionspace.Accounts

  action_fallback(MissionspaceWeb.FallbackController)

  def register(conn, %{
        "workspace_name" => workspace_name,
        "name" => name,
        "email" => email,
        "password" => password
      }) do
    case Accounts.register_workspace_and_user(workspace_name, name, email, password) do
      {:ok, %{workspace: workspace, user: user}} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:workspace_id, workspace.id)
        |> put_status(:created)
        |> json(%{
          user: %{
            id: user.id,
            name: user.name,
            email: user.email,
            avatar: user.avatar,
            timezone: user.timezone,
            role: user.role,
            workspace_id: workspace.id
          },
          workspace: %{
            id: workspace.id,
            name: workspace.name,
            slug: workspace.slug,
            logo: workspace.logo
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        # Set session so resend-verification works
        conn =
          conn
          |> put_session(:user_id, user.id)
          |> put_session(:workspace_id, user.workspace_id)

        if is_nil(user.email_verified_at) do
          conn
          |> put_status(:forbidden)
          |> json(%{error: "email_not_verified"})
        else
          conn
          |> json(%{
            user: %{
              id: user.id,
              name: user.name,
              email: user.email,
              avatar: user.avatar,
              timezone: user.timezone,
              role: user.role,
              workspace_id: user.workspace_id
            },
            workspace: %{
              id: user.workspace.id,
              name: user.workspace.name,
              slug: user.workspace.slug,
              logo: user.workspace.logo
            }
          })
        end

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> json(%{message: "Logged out successfully"})
  end

  def me(conn, _params) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})

      user_id ->
        case Accounts.get_user(user_id) do
          {:ok, user} ->
            user = Missionspace.Repo.preload(user, :workspace)

            if is_nil(user.email_verified_at) do
              conn
              |> put_status(:forbidden)
              |> json(%{error: "email_not_verified"})
            else
              json(conn, %{
                user: %{
                  id: user.id,
                  name: user.name,
                  email: user.email,
                  avatar: user.avatar,
                  timezone: user.timezone,
                  role: user.role,
                  workspace_id: user.workspace_id
                },
                workspace: %{
                  id: user.workspace.id,
                  name: user.workspace.name,
                  slug: user.workspace.slug,
                  logo: user.workspace.logo
                }
              })
            end

          {:error, :not_found} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "User not found"})
        end
    end
  end

  def update_me(conn, %{"user" => user_params}) do
    current_user = conn.assigns.current_user

    # Only allow updating name, email, avatar, and timezone
    allowed_params = Map.take(user_params, ["name", "email", "avatar", "timezone"])

    case Accounts.update_user(current_user, allowed_params) do
      {:ok, user} ->
        user = Missionspace.Repo.preload(user, :workspace)

        json(conn, %{
          user: %{
            id: user.id,
            name: user.name,
            email: user.email,
            avatar: user.avatar,
            timezone: user.timezone,
            role: user.role,
            workspace_id: user.workspace_id
          },
          workspace: %{
            id: user.workspace.id,
            name: user.workspace.name,
            slug: user.workspace.slug,
            logo: user.workspace.logo
          }
        })

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
end
