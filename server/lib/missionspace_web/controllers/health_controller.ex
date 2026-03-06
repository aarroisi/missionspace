defmodule MissionspaceWeb.HealthController do
  use MissionspaceWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
