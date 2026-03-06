defmodule BridgeWeb.ApiKeyControllerTest do
  use BridgeWeb.ConnCase

  alias Bridge.ApiKeys

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id, role: "owner")

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, user: user}
  end

  describe "index" do
    test "lists API keys without plaintext key", %{conn: conn, user: user} do
      {:ok, _created} = ApiKeys.create_api_key_for_user(user, %{"name" => "Automation"})

      response =
        conn
        |> get(~p"/api/api-keys")
        |> json_response(200)

      assert length(response["data"]) == 1
      assert response["data"] |> hd() |> Map.get("name") == "Automation"
      refute Map.has_key?(response["data"] |> hd(), "key")
    end
  end

  describe "create" do
    test "creates API key and returns plaintext key once", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/api-keys", %{name: "CI key"})
        |> json_response(201)

      assert response["data"]["name"] == "CI key"
      assert String.starts_with?(response["data"]["key"], ApiKeys.api_key_prefix())
      assert response["data"]["verify_endpoint"] == "/api/api-keys/verify"
    end

    test "rejects invalid scopes", %{conn: conn} do
      response =
        conn
        |> post(~p"/api/api-keys", %{name: "Invalid", scopes: ["not:real:scope"]})
        |> json_response(422)

      assert response["errors"]["scopes"]
    end
  end

  describe "delete" do
    test "revokes API key", %{conn: conn} do
      create_response =
        conn
        |> post(~p"/api/api-keys", %{name: "Temp key"})
        |> json_response(201)

      key_id = create_response["data"]["id"]
      plaintext_key = create_response["data"]["key"]

      conn
      |> delete(~p"/api/api-keys/#{key_id}")
      |> response(204)

      verify_conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-api-key", plaintext_key)

      unauthorized_response =
        verify_conn
        |> get(~p"/api/api-keys/verify")
        |> json_response(401)

      assert unauthorized_response["errors"]["detail"] == "Unauthorized"
    end
  end

  describe "verify" do
    test "validates API key", %{user: user} do
      {:ok, %{plaintext_key: plaintext_key, api_key: api_key}} =
        ApiKeys.create_api_key_for_user(user, %{"name" => "Verifier"})

      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("x-api-key", plaintext_key)

      response =
        conn
        |> get(~p"/api/api-keys/verify")
        |> json_response(200)

      assert response["data"]["valid"] == true
      assert response["data"]["auth_method"] == "api_key"
      assert response["data"]["api_key"]["id"] == api_key.id
      assert response["data"]["user"]["id"] == user.id
    end

    test "requires API key authentication", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/api-keys/verify")
        |> json_response(400)

      assert response["error"] == "API key required"
    end
  end
end
