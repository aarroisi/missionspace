defmodule MissionspaceWeb.TaskChannel do
  use MissionspaceWeb, :channel

  alias Missionspace.Lists
  alias Missionspace.Chat
  alias Missionspace.Repo

  @impl true
  def join("task:" <> task_id, _payload, socket) do
    # Verify that the task exists and user has access
    case Lists.get_task(task_id) do
      {:ok, _task} ->
        # You could add additional authorization checks here
        # For now, we allow any authenticated user to join
        socket = assign(socket, :task_id, task_id)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "task not found"}}
    end
  end

  @impl true
  def handle_in("update_status", %{"status" => status}, socket) do
    task_id = socket.assigns.task_id

    case Lists.get_task(task_id) do
      {:ok, task} ->
        case Lists.update_task(task, %{status: status}) do
          {:ok, updated_task} ->
            # Preload associations for broadcasting
            updated_task = Repo.preload(updated_task, [:assignee, :created_by, :list])

            # Broadcast the status update to all subscribers
            broadcast!(socket, "status_updated", %{
              task_id: task_id,
              status: status,
              task: updated_task
            })

            {:reply, {:ok, %{task: updated_task}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "task not found"}}, socket}
    end
  end

  @impl true
  def handle_in("update_task", %{"updates" => updates}, socket) do
    task_id = socket.assigns.task_id

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
  def handle_in("new_comment", %{"text" => text}, socket) do
    task_id = socket.assigns.task_id
    user_id = socket.assigns.user_id

    comment_params = %{
      text: text,
      entity_type: "task",
      entity_id: task_id,
      user_id: user_id
    }

    case Chat.create_message(comment_params) do
      {:ok, message} ->
        # Preload associations for broadcasting
        message = Repo.preload(message, [:user, :parent, :quote])

        # Broadcast the new comment to all subscribers
        broadcast!(socket, "comment_added", %{
          comment: message,
          task_id: task_id
        })

        {:reply, {:ok, %{comment: message}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("assign_user", %{"user_id" => assignee_id}, socket) do
    task_id = socket.assigns.task_id

    case Lists.get_task(task_id) do
      {:ok, task} ->
        case Lists.update_task(task, %{assignee_id: assignee_id}) do
          {:ok, updated_task} ->
            # Preload associations for broadcasting
            updated_task = Repo.preload(updated_task, [:assignee, :created_by, :list])

            # Broadcast the assignment to all subscribers
            broadcast!(socket, "user_assigned", %{
              task_id: task_id,
              assignee: updated_task.assignee,
              task: updated_task
            })

            {:reply, {:ok, %{task: updated_task}}, socket}

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
