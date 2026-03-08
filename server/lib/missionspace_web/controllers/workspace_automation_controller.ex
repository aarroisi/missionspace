defmodule MissionspaceWeb.WorkspaceAutomationController do
  use MissionspaceWeb, :controller

  require Logger

  alias Missionspace.Automation
  alias Missionspace.Authorization.Policy

  action_fallback(MissionspaceWeb.FallbackController)

  plug(:authorize)

  def show(conn, _params) do
    with {:ok, setting} <- Automation.get_workspace_setting(conn.assigns.workspace_id) do
      json(conn, %{automation: automation_payload(setting)})
    end
  end

  def github_connection(conn, _params) do
    workspace_id = conn.assigns.workspace_id
    user_id = conn.assigns.current_user.id

    with {:ok, connection} <- Automation.get_github_connection(workspace_id) do
      json(conn, %{
        github_connection: %{
          provider: connection.provider,
          status: connection.status,
          connected: connection.connected,
          installation_id: connection.installation_id,
          connect_url: build_github_connect_url(workspace_id, user_id),
          repository_count: connection.repository_count,
          account_login: connection.account_login,
          account_type: connection.account_type,
          account_avatar_url: connection.account_avatar_url,
          account_url: connection.account_url,
          app_slug: connection.app_slug,
          repository_selection: connection.repository_selection
        }
      })
    end
  end

  def codex_connection(conn, _params) do
    workspace_id = conn.assigns.workspace_id
    user_id = conn.assigns.current_user.id

    with {:ok, connection} <- Automation.get_codex_connection(workspace_id, user_id) do
      json(conn, %{codex_connection: connection})
    end
  end

  def link_codex_connection(conn, %{"code" => code, "state" => state}) do
    workspace_id = conn.assigns.workspace_id
    user_id = conn.assigns.current_user.id

    case Automation.connect_codex_oauth(workspace_id, user_id, code, state) do
      {:ok, setting} ->
        json(conn, %{automation: automation_payload(setting)})

      {:error, :invalid_state} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{state: ["is invalid or expired"]}})

      {:error, :codex_oauth_not_configured} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{codex_connection: ["OAuth is not configured on the server"]}})

      {:error, :codex_oauth_missing_credential} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{codex_connection: ["did not return a usable Codex credential"]}})

      {:error, {:codex_oauth_request_failed, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: %{codex_connection: ["OAuth token exchange failed: #{inspect(reason)}"]}
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  def link_codex_connection(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{code: ["is required"], state: ["is required"]}})
  end

  def start_codex_device_authorization(conn, _params) do
    workspace_id = conn.assigns.workspace_id

    case Automation.start_codex_device_authorization(workspace_id) do
      {:ok, session} ->
        json(conn, %{codex_device_authorization: session})

      {:error, :codex_oauth_not_configured} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{codex_connection: ["OAuth is not configured on the server"]}})

      {:error, {:codex_oauth_request_failed, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{codex_connection: ["OAuth start failed: #{inspect(reason)}"]}})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def complete_codex_device_authorization(conn, %{
        "device_auth_id" => device_auth_id,
        "user_code" => user_code
      }) do
    workspace_id = conn.assigns.workspace_id

    case Automation.complete_codex_device_authorization(workspace_id, device_auth_id, user_code) do
      {:ok, setting} ->
        json(conn, %{automation: automation_payload(setting)})

      {:pending, details} ->
        conn
        |> put_status(:accepted)
        |> json(%{codex_device_authorization: Map.put(details, :status, "pending")})

      {:error, :codex_oauth_missing_credential} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{codex_connection: ["did not return a usable Codex credential"]}})

      {:error, {:codex_oauth_request_failed, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{codex_connection: ["OAuth completion failed: #{inspect(reason)}"]}})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def complete_codex_device_authorization(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{device_auth_id: ["is required"], user_code: ["is required"]}})
  end

  def unlink_codex_connection(conn, _params) do
    workspace_id = conn.assigns.workspace_id

    case Automation.disconnect_codex_connection(workspace_id) do
      {:ok, setting} ->
        json(conn, %{automation: automation_payload(setting)})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def link_github_connection(conn, %{"installation_id" => installation_id, "state" => state}) do
    workspace_id = conn.assigns.workspace_id
    user_id = conn.assigns.current_user.id

    with {:ok, _claims} <- verify_github_connect_state(state, workspace_id, user_id),
         {:ok, setting} <- Automation.link_github_installation(workspace_id, installation_id) do
      setting = maybe_sync_github_repositories(workspace_id, setting)
      json(conn, %{automation: automation_payload(setting)})
    else
      {:error, :invalid_installation_id} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{installation_id: ["must be a numeric GitHub installation id"]}})

      {:error, :invalid_state} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{state: ["is invalid or expired"]}})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def link_github_connection(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{installation_id: ["is required"], state: ["is required"]}})
  end

  def unlink_github_connection(conn, _params) do
    workspace_id = conn.assigns.workspace_id

    case Automation.unlink_github_installation(workspace_id) do
      {:ok, setting} ->
        json(conn, %{automation: automation_payload(setting)})

      {:error, {:github_disconnect_failed, {:github_request_failed, status}}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: %{github_connection: ["failed to disconnect installation (#{inspect(status)})"]}
        })

      {:error, {:github_disconnect_failed, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          errors: %{github_connection: ["failed to disconnect installation: #{inspect(reason)}"]}
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sync_github_repositories(conn, _params) do
    workspace_id = conn.assigns.workspace_id

    case Automation.sync_workspace_repositories_from_github(workspace_id) do
      {:ok, setting} ->
        json(conn, %{automation: automation_payload(setting)})

      {:error, :github_app_installation_not_configured} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{github_connection: ["must be connected first"]}})

      {:error, :github_app_not_configured} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{github_connection: ["is not configured on the server"]}})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update(conn, %{"automation" => automation_params}) do
    workspace_id = conn.assigns.workspace_id
    automation_params = drop_repository_params(automation_params)

    case Automation.update_workspace_setting(workspace_id, automation_params) do
      {:ok, setting} ->
        json(conn, %{automation: automation_payload(setting)})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{automation: ["is required"]}})
  end

  defp authorize(conn, _opts) do
    user = conn.assigns.current_user

    if Policy.can?(user, :manage_workspace_automation, nil) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Forbidden"})
      |> halt()
    end
  end

  defp automation_payload(setting) do
    %{
      id: setting.id,
      provider: setting.provider,
      github_app_installation_id: setting.github_app_installation_id,
      execution_environment: "isolated",
      autonomous_execution_enabled: setting.autonomous_execution_enabled,
      auto_open_prs: setting.auto_open_prs,
      codex_api_key_configured: not is_nil(setting.codex_api_key_ciphertext),
      codex_api_key_last4: setting.codex_api_key_last4,
      codex_api_key_updated_at: setting.codex_api_key_updated_at,
      codex_auth_method: automation_codex_auth_method(setting),
      codex_oauth_account_id: setting.codex_oauth_account_id,
      codex_oauth_plan_type: setting.codex_oauth_plan_type,
      repositories:
        Enum.map(setting.repositories, fn repository ->
          %{
            id: repository.id,
            provider: repository.provider,
            repo_owner: repository.repo_owner,
            repo_name: repository.repo_name,
            default_branch: repository.default_branch,
            enabled: repository.enabled
          }
        end)
    }
  end

  defp maybe_sync_github_repositories(workspace_id, fallback_setting) do
    case Automation.sync_workspace_repositories_from_github(workspace_id) do
      {:ok, synced_setting} ->
        synced_setting

      {:error, :github_app_not_configured} ->
        fallback_setting

      {:error, :github_app_installation_not_configured} ->
        fallback_setting

      {:error, reason} ->
        Logger.warning(
          "automation failed to sync GitHub installation repositories: #{inspect(reason)}"
        )

        fallback_setting
    end
  end

  defp drop_repository_params(automation_params) when is_map(automation_params) do
    automation_params
    |> Map.delete("repositories")
    |> Map.delete(:repositories)
    |> Map.delete("codex_auth_method")
    |> Map.delete(:codex_auth_method)
    |> Map.delete("codex_oauth_account_id")
    |> Map.delete(:codex_oauth_account_id)
    |> Map.delete("codex_oauth_plan_type")
    |> Map.delete(:codex_oauth_plan_type)
  end

  defp automation_codex_auth_method(setting) do
    case setting.codex_auth_method do
      method when method in ["api_key", "chatgpt_oauth"] -> method
      _ when is_binary(setting.codex_api_key_ciphertext) -> "api_key"
      _ -> nil
    end
  end

  defp build_github_connect_url(workspace_id, user_id) do
    case Application.get_env(:missionspace, :github_app_install_url) do
      nil ->
        nil

      "" ->
        nil

      base_url ->
        state = sign_github_connect_state(workspace_id, user_id)

        uri = URI.parse(base_url)

        query =
          (uri.query || "")
          |> URI.decode_query()
          |> Map.put("state", state)

        uri
        |> Map.put(:query, URI.encode_query(query))
        |> URI.to_string()
    end
  end

  defp sign_github_connect_state(workspace_id, user_id) do
    Phoenix.Token.sign(MissionspaceWeb.Endpoint, "github-app-connect", %{
      workspace_id: workspace_id,
      user_id: user_id
    })
  end

  defp verify_github_connect_state(state, workspace_id, user_id) do
    case Phoenix.Token.verify(MissionspaceWeb.Endpoint, "github-app-connect", state,
           max_age: 15 * 60
         ) do
      {:ok, claims} when is_map(claims) ->
        claims_workspace_id = Map.get(claims, "workspace_id") || Map.get(claims, :workspace_id)
        claims_user_id = Map.get(claims, "user_id") || Map.get(claims, :user_id)

        if claims_workspace_id == workspace_id and claims_user_id == user_id do
          {:ok, claims}
        else
          {:error, :invalid_state}
        end

      _ ->
        {:error, :invalid_state}
    end
  end
end
