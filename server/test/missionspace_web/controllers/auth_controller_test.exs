defmodule MissionspaceWeb.AuthControllerTest do
  use MissionspaceWeb.ConnCase

  alias Missionspace.Repo

  describe "login" do
    setup %{conn: conn} do
      workspace = insert(:workspace)

      user =
        insert(:user,
          workspace_id: workspace.id,
          email: "login@example.com",
          password_hash: Missionspace.Accounts.User.hash_password("password123")
        )

      conn = put_req_header(conn, "accept", "application/json")

      {:ok, conn: conn, user: user}
    end

    test "sets a persistent session cookie", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/login", %{
          email: user.email,
          password: "password123"
        })

      response = json_response(conn, 200)
      assert response["user"]["id"] == user.id

      session_cookie =
        conn
        |> get_resp_header("set-cookie")
        |> Enum.find(&String.starts_with?(&1, "_missionspace_key="))

      assert session_cookie
      assert session_cookie =~ ~r/max-age=1209600/i
      assert session_cookie =~ ~r/expires=/i
      assert get_session(conn, :current_device_account_id)

      accounts_response =
        conn
        |> recycle()
        |> get(~p"/api/auth/accounts")
        |> json_response(200)

      assert length(accounts_response["data"]) == 1
      account = hd(accounts_response["data"])
      assert account["current"] == true
      assert account["state"] == "available"
      assert account["user"]["id"] == user.id
    end
  end

  describe "accounts" do
    setup do
      workspace_1 = insert(:workspace)
      workspace_2 = insert(:workspace)
      user_1 = insert(:user, workspace_id: workspace_1.id)
      user_2 = insert(:user, workspace_id: workspace_2.id)
      device_token = "device-token"
      device_session = insert(:device_session, token_hash: hash_token(device_token))

      account_1 =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user_1.id
        )

      _account_2 =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user_2.id,
          signed_out_at: DateTime.utc_now(),
          session_token_hash: nil,
          session_token_expires_at: nil
        )

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user_1.id)
        |> put_session(:workspace_id, workspace_1.id)
        |> put_session(:current_device_account_id, account_1.id)
        |> put_req_cookie("ms_device", device_token)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user_1: user_1, user_2: user_2}
    end

    test "lists remembered accounts and marks current", %{
      conn: conn,
      user_1: user_1,
      user_2: user_2
    } do
      response =
        conn
        |> get(~p"/api/auth/accounts")
        |> json_response(200)

      assert length(response["data"]) == 2

      account_1 = Enum.find(response["data"], &(&1["user"]["id"] == user_1.id))
      account_2 = Enum.find(response["data"], &(&1["user"]["id"] == user_2.id))

      assert account_1["current"] == true
      assert account_1["state"] == "available"
      assert account_2["current"] == false
      assert account_2["state"] == "signed_out"
    end
  end

  describe "switch_account" do
    setup do
      workspace_1 = insert(:workspace)
      workspace_2 = insert(:workspace)
      user_1 = insert(:user, workspace_id: workspace_1.id)
      user_2 = insert(:user, workspace_id: workspace_2.id)
      device_token = "switch-device-token"
      device_session = insert(:device_session, token_hash: hash_token(device_token))

      account_1 =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user_1.id
        )

      account_2 =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user_2.id
        )

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user_1.id)
        |> put_session(:workspace_id, workspace_1.id)
        |> put_session(:current_device_account_id, account_1.id)
        |> put_req_cookie("ms_device", device_token)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user_1: user_1, user_2: user_2, account_2: account_2}
    end

    test "switches to an available remembered account", %{
      conn: conn,
      user_2: user_2,
      account_2: account_2
    } do
      conn =
        post(conn, ~p"/api/auth/switch-account", %{
          user_id: user_2.id
        })

      response = json_response(conn, 200)
      assert response["user"]["id"] == user_2.id
      assert get_session(conn, :user_id) == user_2.id
      assert get_session(conn, :workspace_id) == user_2.workspace_id
      assert get_session(conn, :current_device_account_id) == account_2.id
    end

    test "rejects switching to a non-remembered account", %{conn: conn} do
      unknown_user = insert(:user)

      response =
        conn
        |> post(~p"/api/auth/switch-account", %{user_id: unknown_user.id})
        |> json_response(403)

      assert response["error"] == "account_not_available"
    end

    test "requires reauth for a signed-out remembered account", %{conn: conn, user_2: user_2} do
      device_account =
        Repo.get_by!(Missionspace.Accounts.DeviceSessionAccount, user_id: user_2.id)

      {:ok, _device_account} =
        device_account
        |> Ecto.Changeset.change(%{
          signed_out_at: DateTime.utc_now(),
          session_token_hash: nil,
          session_token_expires_at: nil
        })
        |> Repo.update()

      response =
        conn
        |> post(~p"/api/auth/switch-account", %{user_id: user_2.id})
        |> json_response(403)

      assert response["error"] == "reauth_required"
    end
  end

  describe "add_account" do
    setup do
      workspace = insert(:workspace)
      current_user = insert(:user, workspace_id: workspace.id)

      added_user =
        insert(:user,
          workspace_id: insert(:workspace).id,
          email: "second-login@example.com",
          password_hash: Missionspace.Accounts.User.hash_password("password123")
        )

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, current_user.id)
        |> put_session(:workspace_id, current_user.workspace_id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, current_user: current_user, added_user: added_user}
    end

    test "adds another account without changing current session", %{
      conn: conn,
      current_user: current_user,
      added_user: added_user
    } do
      conn =
        post(conn, ~p"/api/auth/add-account", %{
          email: added_user.email,
          password: "password123"
        })

      response = json_response(conn, 200)
      assert response["data"]["user"]["id"] == added_user.id
      assert response["data"]["state"] == "available"
      assert get_session(conn, :user_id) == current_user.id
      assert get_session(conn, :workspace_id) == current_user.workspace_id

      accounts_response =
        conn
        |> recycle()
        |> get(~p"/api/auth/accounts")
        |> json_response(200)

      assert Enum.any?(accounts_response["data"], &(&1["user"]["id"] == added_user.id))
    end
  end

  describe "logout" do
    setup do
      workspace_1 = insert(:workspace)
      workspace_2 = insert(:workspace)
      user_1 = insert(:user, workspace_id: workspace_1.id)
      user_2 = insert(:user, workspace_id: workspace_2.id)
      device_token = "logout-device-token"
      device_session = insert(:device_session, token_hash: hash_token(device_token))

      account_1 =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user_1.id
        )

      _account_2 =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user_2.id
        )

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user_1.id)
        |> put_session(:workspace_id, workspace_1.id)
        |> put_session(:current_device_account_id, account_1.id)
        |> put_req_cookie("ms_device", device_token)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user_1: user_1, user_2: user_2}
    end

    test "signs out current account and keeps it on the device list", %{
      conn: conn,
      user_1: user_1,
      user_2: user_2
    } do
      conn = post(conn, ~p"/api/auth/logout", %{})

      response = json_response(conn, 200)
      assert response["message"] == "Logged out successfully"
      assert get_session(conn, :user_id) == nil
      assert get_session(conn, :workspace_id) == nil
      assert get_session(conn, :current_device_account_id) == nil

      accounts_response =
        conn
        |> recycle()
        |> get(~p"/api/auth/accounts")
        |> json_response(200)

      assert Enum.find(accounts_response["data"], &(&1["user"]["id"] == user_1.id))["state"] ==
               "signed_out"

      assert Enum.find(accounts_response["data"], &(&1["user"]["id"] == user_2.id))["state"] ==
               "available"
    end
  end

  describe "sign_out_account" do
    setup do
      workspace_1 = insert(:workspace)
      workspace_2 = insert(:workspace)
      current_user = insert(:user, workspace_id: workspace_1.id)
      other_user = insert(:user, workspace_id: workspace_2.id)
      device_token = "account-sign-out-device-token"
      device_session = insert(:device_session, token_hash: hash_token(device_token))

      current_account =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: current_user.id
        )

      _other_account =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: other_user.id
        )

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, current_user.id)
        |> put_session(:workspace_id, current_user.workspace_id)
        |> put_session(:current_device_account_id, current_account.id)
        |> put_req_cookie("ms_device", device_token)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, current_user: current_user, other_user: other_user}
    end

    test "signs out a specific non-current account without removing it", %{
      conn: conn,
      other_user: other_user
    } do
      response =
        conn
        |> post(~p"/api/auth/sign-out-account", %{user_id: other_user.id})
        |> json_response(200)

      assert response["data"]["user"]["id"] == other_user.id
      assert response["data"]["state"] == "signed_out"

      accounts_response =
        conn
        |> recycle()
        |> get(~p"/api/auth/accounts")
        |> json_response(200)

      assert Enum.find(accounts_response["data"], &(&1["user"]["id"] == other_user.id))["state"] ==
               "signed_out"
    end
  end

  describe "reauth_account" do
    setup do
      workspace = insert(:workspace)

      user =
        insert(:user,
          workspace_id: workspace.id,
          email: "reauth@example.com",
          password_hash: Missionspace.Accounts.User.hash_password("password123")
        )

      device_token = "reauth-device-token"
      device_session = insert(:device_session, token_hash: hash_token(device_token))

      _device_account =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user.id,
          signed_out_at: DateTime.utc_now(),
          session_token_hash: nil,
          session_token_expires_at: nil
        )

      conn =
        build_conn()
        |> put_req_cookie("ms_device", device_token)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user: user}
    end

    test "reauthenticates a remembered signed-out account", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/api/auth/reauth-account", %{
          user_id: user.id,
          password: "password123"
        })

      response = json_response(conn, 200)
      assert response["user"]["id"] == user.id
      assert get_session(conn, :user_id) == user.id
      assert get_session(conn, :current_device_account_id)

      accounts_response =
        conn
        |> recycle()
        |> get(~p"/api/auth/accounts")
        |> json_response(200)

      assert Enum.find(accounts_response["data"], &(&1["user"]["id"] == user.id))["state"] ==
               "available"
    end
  end

  describe "remove_account" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      device_token = "remove-device-token"
      device_session = insert(:device_session, token_hash: hash_token(device_token))

      _device_account =
        insert(:device_session_account,
          device_session_id: device_session.id,
          user_id: user.id,
          signed_out_at: DateTime.utc_now(),
          session_token_hash: nil,
          session_token_expires_at: nil
        )

      conn =
        build_conn()
        |> put_req_cookie("ms_device", device_token)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user: user}
    end

    test "removes a remembered account from the device", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/api/auth/accounts/#{user.id}")
      response(conn, 204)

      accounts_response =
        conn
        |> recycle()
        |> get(~p"/api/auth/accounts")
        |> json_response(200)

      assert accounts_response["data"] == []
    end
  end

  describe "update_me" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id, name: "Old Name", email: "old@example.com")

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user.id)
        |> put_req_header("accept", "application/json")

      {:ok, conn: conn, user: user, workspace: workspace}
    end

    test "updates user name successfully", %{conn: conn} do
      response =
        conn
        |> put(~p"/api/auth/me", user: %{name: "New Name"})
        |> json_response(200)

      assert response["user"]["name"] == "New Name"
    end

    test "updates user email successfully", %{conn: conn} do
      response =
        conn
        |> put(~p"/api/auth/me", user: %{email: "new@example.com"})
        |> json_response(200)

      assert response["user"]["email"] == "new@example.com"
    end

    test "updates user timezone successfully", %{conn: conn} do
      response =
        conn
        |> put(~p"/api/auth/me", user: %{timezone: "America/New_York"})
        |> json_response(200)

      assert response["user"]["timezone"] == "America/New_York"
    end

    test "updates both name and email at once", %{conn: conn} do
      response =
        conn
        |> put(~p"/api/auth/me", user: %{name: "New Name", email: "new@example.com"})
        |> json_response(200)

      assert response["user"]["name"] == "New Name"
      assert response["user"]["email"] == "new@example.com"
    end

    test "returns workspace info in response", %{conn: conn, workspace: workspace} do
      response =
        conn
        |> put(~p"/api/auth/me", user: %{name: "New Name"})
        |> json_response(200)

      assert response["workspace"]["id"] == workspace.id
      assert response["workspace"]["name"] == workspace.name
      assert response["workspace"]["slug"] == workspace.slug
    end

    test "returns error for invalid email format", %{conn: conn} do
      response =
        conn
        |> put(~p"/api/auth/me", user: %{email: "invalid"})
        |> json_response(422)

      assert response["errors"]["email"]
    end

    test "returns error for empty name", %{conn: conn} do
      response =
        conn
        |> put(~p"/api/auth/me", user: %{name: ""})
        |> json_response(422)

      assert response["errors"]["name"]
    end

    test "returns 401 when not authenticated" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")

      conn
      |> put(~p"/api/auth/me", user: %{name: "Test"})
      |> json_response(401)
    end

    test "returns error for duplicate email", %{conn: conn, workspace: workspace} do
      _other_user = insert(:user, workspace_id: workspace.id, email: "taken@example.com")

      response =
        conn
        |> put(~p"/api/auth/me", user: %{email: "taken@example.com"})
        |> json_response(422)

      assert response["errors"]["email"]
    end
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end
end
