defmodule Bridge.Repo.Migrations.AddStarredToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :starred, :boolean, default: false, null: false
    end
  end
end
