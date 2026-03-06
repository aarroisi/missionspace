defmodule Missionspace.Repo.Migrations.AddUniqueChannelNamePerWorkspace do
  use Ecto.Migration

  def change do
    create unique_index(:channels, [:workspace_id, :name])
  end
end
