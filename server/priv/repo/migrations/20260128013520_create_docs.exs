defmodule Missionspace.Repo.Migrations.CreateDocs do
  use Ecto.Migration

  def change do
    create table(:docs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:title, :string, null: false)
      add(:content, :text, default: "", null: false)
      add(:starred, :boolean, default: false, null: false)
      add(:project_id, references(:projects, type: :binary_id, on_delete: :nilify_all))
      add(:author_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false)

      timestamps(type: :timestamptz)
    end

    create(index(:docs, [:project_id]))
    create(index(:docs, [:author_id]))
  end
end
