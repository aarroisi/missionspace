defmodule Missionspace.Repo.Migrations.AddCreatedByToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    create(index(:projects, [:created_by_id]))
  end
end
