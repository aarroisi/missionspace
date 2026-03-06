defmodule Missionspace.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:title, :string, null: false)
      add(:status, :string, default: "todo", null: false)
      add(:notes, :text)
      add(:due_on, :date)
      add(:list_id, references(:lists, type: :binary_id, on_delete: :delete_all), null: false)
      add(:assignee_id, references(:users, type: :binary_id, on_delete: :nilify_all))

      add(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false
      )

      timestamps(type: :timestamptz)
    end

    create(index(:tasks, [:list_id]))
    create(index(:tasks, [:assignee_id]))
    create(index(:tasks, [:created_by_id]))
    create(index(:tasks, [:status]))
  end
end
