defmodule Missionspace.Repo do
  use Ecto.Repo,
    otp_app: :missionspace,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
