defmodule BridgeWeb.DocController do
  use BridgeWeb, :controller

  alias Bridge.Docs
  alias Bridge.Mentions
  alias Bridge.Authorization.Policy
  import BridgeWeb.PaginationHelpers
  import Plug.Conn

  action_fallback(BridgeWeb.FallbackController)

  plug(:load_resource when action in [:show, :update, :delete])
  plug(:authorize, :view_item when action in [:show])
  plug(:authorize, :create_item when action in [:create])
  plug(:authorize, :update_item when action in [:update])
  plug(:authorize, :delete_item when action in [:delete])

  defp load_resource(conn, _opts) do
    case Docs.get_doc(conn.params["id"], conn.assigns.workspace_id) do
      {:ok, doc} ->
        assign(conn, :doc, doc)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  defp authorize(conn, permission) do
    user = conn.assigns.current_user
    resource = get_authorization_resource(conn, permission)

    if Policy.can?(user, permission, resource) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.json(%{error: "Forbidden"})
      |> halt()
    end
  end

  defp get_authorization_resource(conn, :create_item) do
    # For create, we check project_id from params
    conn.params["project_id"]
  end

  defp get_authorization_resource(conn, _permission) do
    conn.assigns[:doc]
  end

  def index(conn, %{"starred" => "true"} = params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user
    opts = build_pagination_opts(params)
    page = Docs.list_starred_docs(workspace_id, user.id, opts)
    entries = Bridge.Stars.mark_starred(page.entries, user.id, "doc")
    render(conn, :index, page: %{page | entries: entries})
  end

  def index(conn, params) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    opts = build_pagination_opts(params)

    opts =
      case params["doc_folder_id"] do
        nil -> opts
        folder_id -> Keyword.put(opts, :doc_folder_id, folder_id)
      end

    page = Docs.list_docs(workspace_id, user, opts)
    entries = Bridge.Stars.mark_starred(page.entries, user.id, "doc")

    render(conn, :index, page: %{page | entries: entries})
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id

    doc_params =
      params
      |> Map.put("author_id", current_user.id)
      |> Map.put("workspace_id", workspace_id)

    with {:ok, doc} <- Docs.create_doc(doc_params) do
      conn
      |> put_status(:created)
      |> render(:show, doc: doc)
    end
  end

  def show(conn, _params) do
    user = conn.assigns.current_user
    doc = Bridge.Stars.mark_starred(conn.assigns.doc, user.id, "doc")
    render(conn, :show, doc: doc)
  end

  def update(conn, params) do
    doc = conn.assigns.doc
    current_user = conn.assigns.current_user
    old_content = doc.content || ""
    doc_params = Map.drop(params, ["id"])

    with {:ok, updated_doc} <- Docs.update_doc(doc, doc_params) do
      # Check for new mentions in content and create notifications
      new_content = updated_doc.content || ""

      if new_content != old_content do
        Task.start(fn ->
          # Find mentions that are in new content but not in old content
          old_mentions = Mentions.extract_mention_ids(old_content) |> MapSet.new()
          new_mentions = Mentions.extract_mention_ids(new_content) |> MapSet.new()
          added_mentions = MapSet.difference(new_mentions, old_mentions) |> MapSet.to_list()

          # Create notifications for newly mentioned users
          Enum.each(added_mentions, fn user_id ->
            if user_id != current_user.id do
              case Bridge.Notifications.create_notification(%{
                     type: "mention",
                     entity_type: "doc",
                     entity_id: updated_doc.id,
                     user_id: user_id,
                     actor_id: current_user.id,
                     context: %{docId: updated_doc.id, docTitle: updated_doc.title}
                   }) do
                {:ok, notification} ->
                  notification = Bridge.Repo.preload(notification, [:actor])
                  Mentions.broadcast_notification(notification)

                _ ->
                  :ok
              end
            end
          end)
        end)
      end

      render(conn, :show, doc: updated_doc)
    end
  end

  def delete(conn, _params) do
    with {:ok, _doc} <- Docs.delete_doc(conn.assigns.doc) do
      send_resp(conn, :no_content, "")
    end
  end
end
