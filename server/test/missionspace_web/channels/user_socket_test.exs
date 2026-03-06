defmodule MissionspaceWeb.UserSocketTest do
  use MissionspaceWeb.ChannelCase, async: true

  alias MissionspaceWeb.{ListChannel, UserSocket}

  describe "connect/3" do
    test "connects with a valid auth token and assigns workspace context" do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      token = Phoenix.Token.sign(MissionspaceWeb.Endpoint, "user socket", user.id)

      assert {:ok, socket} =
               UserSocket.connect(%{}, socket(UserSocket, nil, %{}), %{auth_token: token})

      assert socket.assigns.user_id == user.id
      assert socket.assigns.workspace_id == workspace.id
    end

    test "rejects missing auth tokens" do
      assert :error = UserSocket.connect(%{}, socket(UserSocket, nil, %{}), %{})
    end

    test "allows joining workspace-scoped channels after connect" do
      workspace = insert(:workspace)
      user = insert(:user, workspace_id: workspace.id)
      list = insert(:list, workspace_id: workspace.id)
      token = Phoenix.Token.sign(MissionspaceWeb.Endpoint, "user socket", user.id)

      assert {:ok, socket} =
               UserSocket.connect(%{}, socket(UserSocket, nil, %{}), %{auth_token: token})

      assert {:ok, %{}, joined_socket} =
               subscribe_and_join(socket, ListChannel, "list:#{list.id}")

      assert joined_socket.assigns.list_id == list.id
    end
  end
end
