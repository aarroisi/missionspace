defmodule BridgeWeb.AuthControllerTest do
  use BridgeWeb.ConnCase

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
end
