defmodule MissionspaceWeb.UserSocket do
  use Phoenix.Socket

  alias Missionspace.Accounts

  # Define channels
  channel("list:*", MissionspaceWeb.ListChannel)
  channel("task:*", MissionspaceWeb.TaskChannel)
  channel("doc:*", MissionspaceWeb.DocChannel)
  channel("channel:*", MissionspaceWeb.ChatChannel)
  channel("dm:*", MissionspaceWeb.ChatChannel)
  channel("notifications:*", MissionspaceWeb.NotificationChannel)

  @impl true
  def connect(_params, socket, %{auth_token: token}) when is_binary(token) do
    with {:ok, user_id} <- Phoenix.Token.verify(socket, "user socket", token, max_age: 1_209_600),
         {:ok, user} <- Accounts.get_user(user_id),
         :ok <- validate_user(user) do
      {:ok,
       socket
       |> assign(:user_id, user.id)
       |> assign(:workspace_id, user.workspace_id)}
    else
      _ -> :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  defp validate_user(user) do
    cond do
      not user.is_active -> :error
      is_nil(user.email_verified_at) -> :error
      is_nil(user.workspace_id) -> :error
      true -> :ok
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.MissionspaceWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
