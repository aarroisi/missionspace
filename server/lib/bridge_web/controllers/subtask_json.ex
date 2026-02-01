defmodule BridgeWeb.SubtaskJSON do
  alias Bridge.Lists.Subtask

  @doc """
  Renders a list of subtasks.
  """
  def index(%{subtasks: subtasks}) do
    %{data: for(subtask <- subtasks, do: data(subtask))}
  end

  @doc """
  Renders a single subtask.
  """
  def show(%{subtask: subtask}) do
    %{data: data(subtask)}
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%Subtask{} = subtask) do
    base = %{
      id: subtask.id,
      title: subtask.title,
      is_completed: subtask.is_completed,
      notes: subtask.notes,
      due_on: subtask.due_on,
      completed_at: subtask.completed_at,
      task_id: subtask.task_id,
      assignee_id: subtask.assignee_id,
      assignee: get_assignee(subtask),
      created_by_id: subtask.created_by_id,
      created_by: get_created_by(subtask),
      inserted_at: subtask.inserted_at,
      updated_at: subtask.updated_at
    }

    # Include task info if preloaded
    case subtask.task do
      %{id: _, list_id: board_id, title: task_title} ->
        Map.put(base, :task, %{id: subtask.task_id, board_id: board_id, title: task_title})

      _ ->
        base
    end
  end

  defp get_assignee(%Subtask{assignee: %{id: id, name: name, email: email}}),
    do: %{id: id, name: name, email: email}

  defp get_assignee(_), do: nil

  defp get_created_by(%Subtask{created_by: %{id: id, name: name, email: email}}),
    do: %{id: id, name: name, email: email}

  defp get_created_by(_), do: nil

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
