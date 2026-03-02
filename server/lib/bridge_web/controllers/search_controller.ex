defmodule BridgeWeb.SearchController do
  use BridgeWeb, :controller

  alias Bridge.Search

  action_fallback(BridgeWeb.FallbackController)

  def index(conn, %{"q" => query}) do
    workspace_id = conn.assigns.workspace_id
    user = conn.assigns.current_user

    results = Search.search(query, workspace_id, user)

    render(conn, :index, results: results)
  end

  def index(conn, _params) do
    render(conn, :index,
      results: %{
        projects: [],
        boards: [],
        tasks: [],
        doc_folders: [],
        docs: [],
        channels: [],
        members: []
      }
    )
  end
end
