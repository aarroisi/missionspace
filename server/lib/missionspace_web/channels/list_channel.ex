defmodule MissionspaceWeb.ListChannel do
  use MissionspaceWeb, :channel

  alias Missionspace.Lists
  alias Missionspace.Repo

  @impl true
  def join("list:" <> list_id, _payload, socket) do
    # Verify that the list exists and user has access
    workspace_id = socket.assigns.workspace_id

    case Lists.get_list(list_id, workspace_id) do
      {:ok, _list} ->
        # You could add additional authorization checks here
        # For now, we allow any authenticated user to join
        socket = assign(socket, :list_id, list_id)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "list not found"}}
    end
  end

  @impl true
  def handle_in("new_task", %{"task" => task_params}, socket) do
    list_id = socket.assigns.list_id
    user_id = socket.assigns.user_id

    # Add list_id and created_by_id to the task params
    task_params =
      task_params
      |> Map.put("list_id", list_id)
      |> Map.put("created_by_id", user_id)

    case Lists.create_task(task_params) do
      {:ok, task} ->
        # Preload associations for broadcasting
        task = Repo.preload(task, [:assignee, :created_by, :list])

        # Broadcast the new task to all subscribers
        broadcast!(socket, "task_created", %{task: task})
        {:reply, {:ok, %{task: task}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("update_task", %{"task_id" => task_id, "updates" => updates}, socket) do
    case Lists.get_task(task_id) do
      {:ok, task} ->
        case Lists.update_task(task, updates) do
          {:ok, updated_task} ->
            # Preload associations for broadcasting
            updated_task = Repo.preload(updated_task, [:assignee, :created_by, :list])

            # Broadcast the update to all subscribers
            broadcast!(socket, "task_updated", %{task: updated_task})
            {:reply, {:ok, %{task: updated_task}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "task not found"}}, socket}
    end
  end

  @impl true
  def handle_in("delete_task", %{"task_id" => task_id}, socket) do
    case Lists.get_task(task_id) do
      {:ok, task} ->
        case Lists.delete_task(task) do
          {:ok, _deleted_task} ->
            # Broadcast the deletion to all subscribers
            broadcast!(socket, "task_deleted", %{task_id: task_id})
            {:reply, :ok, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "task not found"}}, socket}
    end
  end

  # Helper function to format changeset errors
  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
