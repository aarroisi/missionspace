defmodule BridgeWeb.WorkspaceMemberJSON do
  alias Bridge.Accounts.User

  def index(%{members: members}) do
    %{data: for(member <- members, do: data(member))}
  end

  def show(%{member: member}) do
    %{data: data(member)}
  end

  defp data(%User{} = user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      avatar: user.avatar,
      timezone: user.timezone,
      online: user.online,
      is_active: user.is_active,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
