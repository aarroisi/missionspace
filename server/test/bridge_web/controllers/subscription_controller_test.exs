defmodule BridgeWeb.SubscriptionControllerTest do
  use BridgeWeb.ConnCase

  alias Bridge.Subscriptions

  setup do
    workspace = insert(:workspace)
    user = insert(:user, workspace_id: workspace.id, role: "owner")
    user2 = insert(:user, workspace_id: workspace.id, role: "member")
    task_id = UUIDv7.generate()

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> put_session(:user_id, user.id)
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn, workspace: workspace, user: user, user2: user2, task_id: task_id}
  end

  describe "index" do
    test "returns subscribers for an item", %{
      conn: conn,
      workspace: workspace,
      user: user,
      task_id: task_id
    } do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      response =
        conn
        |> get(~p"/api/subscriptions/task/#{task_id}")
        |> json_response(200)

      assert length(response["data"]) == 1
      [sub] = response["data"]
      assert sub["user_id"] == user.id
      assert sub["user"]["id"] == user.id
      assert sub["user"]["name"] == user.name
    end

    test "returns empty list when no subscribers", %{conn: conn, task_id: task_id} do
      response =
        conn
        |> get(~p"/api/subscriptions/task/#{task_id}")
        |> json_response(200)

      assert response["data"] == []
    end
  end

  describe "status" do
    test "returns subscribed true when user is subscribed", %{
      conn: conn,
      workspace: workspace,
      user: user,
      task_id: task_id
    } do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      response =
        conn
        |> get(~p"/api/subscriptions/task/#{task_id}/status")
        |> json_response(200)

      assert response["data"]["subscribed"] == true
    end

    test "returns subscribed false when user is not subscribed", %{conn: conn, task_id: task_id} do
      response =
        conn
        |> get(~p"/api/subscriptions/task/#{task_id}/status")
        |> json_response(200)

      assert response["data"]["subscribed"] == false
    end
  end

  describe "create" do
    test "subscribes current user to an item", %{conn: conn, user: user, task_id: task_id} do
      response =
        conn
        |> post(~p"/api/subscriptions/task/#{task_id}")
        |> json_response(201)

      assert response["data"]["item_type"] == "task"
      assert response["data"]["item_id"] == task_id
      assert response["data"]["user_id"] == user.id
      assert Subscriptions.subscribed?("task", task_id, user.id)
    end

    test "is idempotent", %{conn: conn, task_id: task_id} do
      conn
      |> post(~p"/api/subscriptions/task/#{task_id}")
      |> json_response(201)

      conn
      |> post(~p"/api/subscriptions/task/#{task_id}")
      |> json_response(201)
    end
  end

  describe "delete" do
    test "unsubscribes current user from an item", %{
      conn: conn,
      workspace: workspace,
      user: user,
      task_id: task_id
    } do
      Subscriptions.subscribe(%{
        item_type: "task",
        item_id: task_id,
        user_id: user.id,
        workspace_id: workspace.id
      })

      conn
      |> delete(~p"/api/subscriptions/task/#{task_id}")
      |> response(204)

      refute Subscriptions.subscribed?("task", task_id, user.id)
    end

    test "returns 404 when not subscribed", %{conn: conn, task_id: task_id} do
      conn
      |> delete(~p"/api/subscriptions/task/#{task_id}")
      |> json_response(404)
    end
  end
end
