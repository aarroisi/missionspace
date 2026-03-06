defmodule MissionspaceWeb.ProjectMemberJSON do
  alias Missionspace.Projects.ProjectMember

  def index(%{members: members}) do
    %{data: for(member <- members, do: data(member))}
  end

  def show(%{member: member}) do
    %{data: data(member)}
  end

  defp data(%ProjectMember{} = pm) do
    base = %{
      id: pm.id,
      userId: pm.user_id,
      projectId: pm.project_id,
      insertedAt: pm.inserted_at,
      updatedAt: pm.updated_at
    }

    if Ecto.assoc_loaded?(pm.user) and pm.user do
      Map.put(base, :user, %{
        id: pm.user.id,
        name: pm.user.name,
        email: pm.user.email,
        avatar: pm.user.avatar
      })
    else
      base
    end
  end
end
