defmodule MissionspaceWeb.WorkspaceAutomationControllerTest do
  use MissionspaceWeb.ConnCase

  alias Missionspace.Automation
  alias Missionspace.Automation.WorkspaceAutomationSetting
  alias Missionspace.Repo

  setup do
    workspace = insert(:workspace)
    owner = insert(:user, workspace_id: workspace.id, role: "owner")
    member = insert(:user, workspace_id: workspace.id, role: "member")

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, owner.id)
      |> put_req_header("accept", "application/json")

    original_install_url = Application.get_env(:missionspace, :github_app_install_url)
    original_codex_oauth_module = Application.get_env(:missionspace, :automation_codex_oauth)

    Application.put_env(
      :missionspace,
      :github_app_install_url,
      "https://github.com/apps/missionspace/installations/new"
    )

    Application.put_env(
      :missionspace,
      :automation_codex_oauth,
      Missionspace.Automation.CodexOAuthStub
    )

    on_exit(fn ->
      Application.put_env(:missionspace, :github_app_install_url, original_install_url)
      Application.put_env(:missionspace, :automation_codex_oauth, original_codex_oauth_module)
    end)

    {:ok, conn: conn, owner: owner, member: member, workspace: workspace}
  end

  describe "show" do
    test "returns default automation settings for owner", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/workspace/automation")
        |> json_response(200)

      assert response["automation"]["provider"] == "codex"
      assert response["automation"]["execution_environment"] == "isolated"
      assert response["automation"]["autonomous_execution_enabled"] == false
      assert response["automation"]["auto_open_prs"] == true
      assert response["automation"]["repositories"] == []
      assert response["automation"]["codex_api_key_configured"] == false
    end

    test "forbids non-owners", %{conn: conn, member: member} do
      conn = conn |> put_session(:user_id, member.id)

      response =
        conn
        |> get(~p"/api/workspace/automation")
        |> json_response(403)

      assert response["error"] == "Forbidden"
    end
  end

  describe "update" do
    test "updates settings but ignores manual repository payload", %{
      conn: conn,
      workspace: workspace
    } do
      params = %{
        "automation" => %{
          "provider" => "codex",
          "sprite_base_url" => "https://example.invalid",
          "sprite_org_slug" => "should-be-ignored",
          "github_app_installation_id" => "123456",
          "default_base_branch" => "release-ignored",
          "autonomous_execution_enabled" => true,
          "auto_open_prs" => true,
          "codex_api_key" => "sk-test-key-1234",
          "repositories" => [
            %{
              "provider" => "github",
              "repo_owner" => "acme",
              "repo_name" => "missionspace",
              "default_branch" => "main",
              "enabled" => true
            }
          ]
        }
      }

      response =
        conn
        |> put(~p"/api/workspace/automation", params)
        |> json_response(200)

      refute Map.has_key?(response["automation"], "sprite_org_slug")
      refute Map.has_key?(response["automation"], "default_base_branch")
      assert response["automation"]["autonomous_execution_enabled"] == true
      assert response["automation"]["codex_api_key_configured"] == true
      assert response["automation"]["codex_api_key_last4"] == "1234"
      assert response["automation"]["codex_auth_method"] == "api_key"
      assert response["automation"]["codex_oauth_account_id"] == nil
      assert response["automation"]["codex_oauth_plan_type"] == nil
      assert response["automation"]["repositories"] == []

      setting = Repo.get_by!(WorkspaceAutomationSetting, workspace_id: workspace.id)
      assert is_binary(setting.codex_api_key_ciphertext)
      assert setting.codex_api_key_last4 == "1234"
      assert setting.sprite_base_url == "https://sprites.dev"
      assert setting.sprite_org_slug == nil
      assert setting.default_base_branch == "main"
    end
  end

  describe "codex_connection" do
    test "returns Codex connection status and connect URL", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/workspace/automation/codex-connection")
        |> json_response(200)

      assert response["codex_connection"]["provider"] == "codex"
      assert response["codex_connection"]["status"] == "not_connected"
      assert response["codex_connection"]["connected"] == false
      assert response["codex_connection"]["auth_method"] == nil
      assert is_binary(response["codex_connection"]["connect_url"])
    end

    test "links Codex OAuth connection with code and state", %{conn: conn} do
      params = %{"code" => "valid-code", "state" => "valid-state"}

      response =
        conn
        |> put(~p"/api/workspace/automation/codex-connection", params)
        |> json_response(200)

      assert response["automation"]["codex_api_key_configured"] == true
      assert response["automation"]["codex_api_key_last4"] == "5678"
      assert response["automation"]["codex_auth_method"] == "chatgpt_oauth"
      assert response["automation"]["codex_oauth_account_id"] == "chatgpt-account-123"
      assert response["automation"]["codex_oauth_plan_type"] == "plus"
    end

    test "rejects invalid Codex OAuth state", %{conn: conn} do
      params = %{"code" => "valid-code", "state" => "expired-state"}

      response =
        conn
        |> put(~p"/api/workspace/automation/codex-connection", params)
        |> json_response(422)

      assert response["errors"]["state"] == ["is invalid or expired"]
    end

    test "rejects OAuth response without usable Codex credential", %{conn: conn} do
      params = %{"code" => "missing-credential", "state" => "valid-state"}

      response =
        conn
        |> put(~p"/api/workspace/automation/codex-connection", params)
        |> json_response(422)

      assert response["errors"]["codex_connection"] == [
               "did not return a usable Codex credential"
             ]
    end

    test "unlinks Codex connection", %{conn: conn, workspace: workspace} do
      {:ok, _setting} =
        Automation.update_workspace_setting(workspace.id, %{
          "codex_api_key" => "sk-test-key-9876",
          "codex_auth_method" => "chatgpt_oauth",
          "codex_oauth_account_id" => "chatgpt-account-123",
          "codex_oauth_plan_type" => "plus"
        })

      response =
        conn
        |> delete(~p"/api/workspace/automation/codex-connection")
        |> json_response(200)

      assert response["automation"]["codex_api_key_configured"] == false
      assert response["automation"]["codex_api_key_last4"] == nil
      assert response["automation"]["codex_auth_method"] == nil
      assert response["automation"]["codex_oauth_account_id"] == nil
      assert response["automation"]["codex_oauth_plan_type"] == nil
    end

    test "starts Codex device authorization", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/workspace/automation/codex-connection/device", %{})
        |> json_response(200)

      assert response["codex_device_authorization"]["device_auth_id"] == "deviceauth_123"
      assert response["codex_device_authorization"]["user_code"] == "K9UQ-CJU67"
      assert response["codex_device_authorization"]["interval_seconds"] == 5

      assert response["codex_device_authorization"]["verification_url"] ==
               "https://auth.openai.com/codex/device"
    end

    test "returns pending while device authorization is not yet approved", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/workspace/automation/codex-connection/device/complete", %{
          "device_auth_id" => "deviceauth_123",
          "user_code" => "K9UQ-CJU67"
        })
        |> json_response(202)

      assert response["codex_device_authorization"]["status"] == "pending"
      assert response["codex_device_authorization"]["interval_seconds"] == 5
    end

    test "completes Codex device authorization when approved", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/workspace/automation/codex-connection/device/complete", %{
          "device_auth_id" => "deviceauth_123",
          "user_code" => "AUTHORIZED-123"
        })
        |> json_response(200)

      assert response["automation"]["codex_api_key_configured"] == true
      assert response["automation"]["codex_api_key_last4"] == "9999"
      assert response["automation"]["codex_auth_method"] == "chatgpt_oauth"
      assert response["automation"]["codex_oauth_account_id"] == "chatgpt-account-999"
      assert response["automation"]["codex_oauth_plan_type"] == "pro"
    end
  end

  describe "github_connection" do
    test "returns GitHub connection status and connect URL", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/workspace/automation/github-connection")
        |> json_response(200)

      assert response["github_connection"]["provider"] == "github_app"
      assert response["github_connection"]["status"] == "not_connected"
      assert response["github_connection"]["connected"] == false
      assert response["github_connection"]["installation_id"] == nil
      assert response["github_connection"]["repository_count"] == 0
      assert response["github_connection"]["account_login"] == nil
      assert response["github_connection"]["account_type"] == nil
      assert is_binary(response["github_connection"]["connect_url"])
      assert String.contains?(response["github_connection"]["connect_url"], "state=")
    end

    test "links GitHub connection when state and installation id are valid", %{
      conn: conn,
      owner: owner,
      workspace: workspace
    } do
      workspace_id = workspace.id

      state =
        Phoenix.Token.sign(MissionspaceWeb.Endpoint, "github-app-connect", %{
          workspace_id: workspace_id,
          user_id: owner.id
        })

      params = %{"installation_id" => "987654", "state" => state}

      response =
        conn
        |> put(~p"/api/workspace/automation/github-connection", params)
        |> json_response(200)

      assert response["automation"]["github_app_installation_id"] == "987654"
    end

    test "rejects invalid state", %{conn: conn} do
      params = %{"installation_id" => "987654", "state" => "bad-state"}

      response =
        conn
        |> put(~p"/api/workspace/automation/github-connection", params)
        |> json_response(422)

      assert response["errors"]["state"] == ["is invalid or expired"]
    end

    test "rejects non-numeric installation id", %{conn: conn, owner: owner, workspace: workspace} do
      workspace_id = workspace.id

      state =
        Phoenix.Token.sign(MissionspaceWeb.Endpoint, "github-app-connect", %{
          workspace_id: workspace_id,
          user_id: owner.id
        })

      params = %{"installation_id" => "abc123", "state" => state}

      response =
        conn
        |> put(~p"/api/workspace/automation/github-connection", params)
        |> json_response(422)

      assert response["errors"]["installation_id"] == [
               "must be a numeric GitHub installation id"
             ]
    end

    test "unlinks GitHub connection", %{conn: conn, workspace: workspace} do
      {:ok, _setting} =
        Automation.update_workspace_setting(workspace.id, %{
          "github_app_installation_id" => "123456",
          "repositories" => [
            %{
              "provider" => "github",
              "repo_owner" => "acme",
              "repo_name" => "missionspace",
              "default_branch" => "main",
              "enabled" => true
            }
          ]
        })

      response =
        conn
        |> delete(~p"/api/workspace/automation/github-connection")
        |> json_response(200)

      assert response["automation"]["github_app_installation_id"] == nil
      assert response["automation"]["repositories"] == []
    end

    test "returns validation error when syncing repositories without GitHub connection", %{
      conn: conn
    } do
      response =
        conn
        |> post(~p"/api/workspace/automation/github-connection/sync", %{})
        |> json_response(422)

      assert response["errors"]["github_connection"] == ["must be connected first"]
    end
  end
end
