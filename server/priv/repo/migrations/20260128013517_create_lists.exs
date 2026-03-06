defmodule Missionspace.Repo.Migrations.CreateLists do
  use Ecto.Migration

  def change do
    create table(:lists, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:starred, :boolean, default: false, null: false)
      add(:project_id, references(:projects, type: :binary_id, on_delete: :nilify_all))

      timestamps(type: :timestamptz)
    end

    create(index(:lists, [:project_id]))
  end
end
