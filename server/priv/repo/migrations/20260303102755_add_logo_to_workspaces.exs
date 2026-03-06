defmodule Missionspace.Repo.Migrations.AddLogoToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :logo, :string
    end
  end
end
