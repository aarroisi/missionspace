defmodule Missionspace.Repo.Migrations.CreateSubtasks do
  use Ecto.Migration

  def change do
    create table(:subtasks, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:title, :string, null: false)
      add(:status, :string, default: "todo", null: false)
      add(:notes, :text)
      add(:task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false)
      add(:assignee_id, references(:users, type: :binary_id, on_delete: :nilify_all))

      add(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false
      )

      timestamps(type: :timestamptz)
    end

    create(index(:subtasks, [:task_id]))
    create(index(:subtasks, [:assignee_id]))
    create(index(:subtasks, [:created_by_id]))
  end
end
