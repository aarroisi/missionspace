defmodule MissionspaceWeb.DocChannel do
  use MissionspaceWeb, :channel

  alias Missionspace.Docs
  alias Missionspace.Chat
  alias Missionspace.Repo

  @impl true
  def join("doc:" <> doc_id, _payload, socket) do
    # Verify that the document exists and user has access
    workspace_id = socket.assigns.workspace_id

    case Docs.get_doc(doc_id, workspace_id) do
      {:ok, _doc} ->
        # You could add additional authorization checks here
        # For now, we allow any authenticated user to join
        socket = assign(socket, :doc_id, doc_id)
        {:ok, socket}

      {:error, :not_found} ->
        {:error, %{reason: "document not found"}}
    end
  end

  @impl true
  def handle_in("update_content", %{"content" => content}, socket) do
    doc_id = socket.assigns.doc_id
    user_id = socket.assigns.user_id
    workspace_id = socket.assigns.workspace_id

    case Docs.get_doc(doc_id, workspace_id) do
      {:ok, doc} ->
        case Docs.update_doc(doc, %{content: content}) do
          {:ok, updated_doc} ->
            # Preload associations for broadcasting
            updated_doc = Repo.preload(updated_doc, [:author, :project])

            # Broadcast the content update to all subscribers (except sender)
            broadcast_from!(socket, "content_updated", %{
              doc_id: doc_id,
              content: content,
              updated_by: user_id,
              doc: updated_doc
            })

            {:reply, {:ok, %{doc: updated_doc}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "document not found"}}, socket}
    end
  end

  @impl true
  def handle_in("update_title", %{"title" => title}, socket) do
    doc_id = socket.assigns.doc_id
    workspace_id = socket.assigns.workspace_id

    case Docs.get_doc(doc_id, workspace_id) do
      {:ok, doc} ->
        case Docs.update_doc(doc, %{title: title}) do
          {:ok, updated_doc} ->
            # Preload associations for broadcasting
            updated_doc = Repo.preload(updated_doc, [:author, :project])

            # Broadcast the title update to all subscribers
            broadcast!(socket, "title_updated", %{
              doc_id: doc_id,
              title: title,
              doc: updated_doc
            })

            {:reply, {:ok, %{doc: updated_doc}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
        end

      {:error, :not_found} ->
        {:reply, {:error, %{reason: "document not found"}}, socket}
    end
  end

  @impl true
  def handle_in("new_comment", %{"text" => text}, socket) do
    doc_id = socket.assigns.doc_id
    user_id = socket.assigns.user_id

    comment_params = %{
      text: text,
      entity_type: "doc",
      entity_id: doc_id,
      user_id: user_id
    }

    case Chat.create_message(comment_params) do
      {:ok, message} ->
        # Preload associations for broadcasting
        message = Repo.preload(message, [:user, :parent, :quote])

        # Broadcast the new comment to all subscribers
        broadcast!(socket, "comment_added", %{
          comment: message,
          doc_id: doc_id
        })

        {:reply, {:ok, %{comment: message}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("cursor_position", %{"position" => position}, socket) do
    user_id = socket.assigns.user_id
    doc_id = socket.assigns.doc_id

    # Broadcast cursor position to other subscribers (not to self)
    broadcast_from!(socket, "cursor_moved", %{
      user_id: user_id,
      position: position,
      doc_id: doc_id
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("toggle_starred", %{}, socket) do
    doc_id = socket.assigns.doc_id
    user_id = socket.assigns.user_id

    case Missionspace.Stars.toggle_star(user_id, "doc", doc_id) do
      {:ok, status} ->
        {:reply, {:ok, %{status: status}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
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
