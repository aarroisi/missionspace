defmodule BridgeWeb.SearchJSON do
  alias Bridge.Projects.Project
  alias Bridge.Lists.List
  alias Bridge.Lists.Task, as: ListTask
  alias Bridge.Docs.{Doc, DocFolder}
  alias Bridge.Chat.Channel
  alias Bridge.Accounts.User

  def index(%{results: results}) do
    %{
      data: %{
        projects: Enum.map(results.projects, &project_data/1),
        boards: Enum.map(results.boards, &board_data/1),
        tasks: Enum.map(results.tasks, &task_data/1),
        doc_folders: Enum.map(results.doc_folders, &doc_folder_data/1),
        docs: Enum.map(results.docs, &doc_data/1),
        channels: Enum.map(results.channels, &channel_data/1),
        members: Enum.map(results.members, &member_data/1)
      }
    }
  end

  defp project_data(%Project{} = p) do
    %{id: p.id, name: p.name, description: p.description}
  end

  defp board_data(%List{} = l) do
    %{id: l.id, name: l.name, prefix: l.prefix}
  end

  defp task_data(%ListTask{} = t) do
    %{
      id: t.id,
      title: t.title,
      key: task_key(t),
      board_id: t.list_id,
      parent_id: t.parent_id,
      status:
        if(t.status, do: %{name: t.status.name, color: t.status.color}, else: nil),
      assignee:
        if(t.assignee, do: %{id: t.assignee.id, name: t.assignee.name}, else: nil)
    }
  end

  defp task_key(%ListTask{list: %List{prefix: prefix}, sequence_number: seq})
       when is_binary(prefix) and is_integer(seq),
       do: "#{prefix}-#{seq}"

  defp task_key(_), do: nil

  defp doc_folder_data(%DocFolder{} = f) do
    %{id: f.id, name: f.name, prefix: f.prefix}
  end

  defp doc_data(%Doc{} = d) do
    %{
      id: d.id,
      title: d.title,
      key: doc_key(d),
      doc_folder_id: d.doc_folder_id
    }
  end

  defp doc_key(%Doc{doc_folder: %DocFolder{prefix: prefix}, sequence_number: seq})
       when is_binary(prefix) and is_integer(seq),
       do: "#{prefix}-#{seq}"

  defp doc_key(_), do: nil

  defp channel_data(%Channel{} = c) do
    %{id: c.id, name: c.name}
  end

  defp member_data(%User{} = u) do
    %{id: u.id, name: u.name, email: u.email, avatar: u.avatar, role: u.role}
  end
end
