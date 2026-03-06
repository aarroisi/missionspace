defmodule Missionspace.Repo.Migrations.RemoveProjectIdFromItems do
  use Ecto.Migration

  def change do
    alter table(:lists) do
      remove(:project_id, references(:projects, type: :binary_id))
    end

    alter table(:docs) do
      remove(:project_id, references(:projects, type: :binary_id))
    end

    alter table(:channels) do
      remove(:project_id, references(:projects, type: :binary_id))
    end
  end
end
