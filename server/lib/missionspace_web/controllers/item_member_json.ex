defmodule MissionspaceWeb.ItemMemberJSON do
  alias Missionspace.Projects.ItemMember

  def index(%{members: members}) do
    %{data: for(member <- members, do: data(member))}
  end

  def show(%{member: member}) do
    %{data: data(member)}
  end

  defp data(%ItemMember{} = member) do
    base = %{
      id: member.id,
      item_type: member.item_type,
      item_id: member.item_id,
      user_id: member.user_id,
      inserted_at: member.inserted_at
    }

    if Ecto.assoc_loaded?(member.user) and member.user do
      Map.put(base, :user, %{
        id: member.user.id,
        name: member.user.name,
        email: member.user.email,
        avatar: member.user.avatar
      })
    else
      base
    end
  end
end
