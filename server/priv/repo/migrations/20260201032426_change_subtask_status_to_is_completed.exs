defmodule Missionspace.Repo.Migrations.ChangeSubtaskStatusToIsCompleted do
  use Ecto.Migration

  def change do
    alter table(:subtasks) do
      add(:is_completed, :boolean, default: false, null: false)
    end

    # Migrate existing data: status "done" -> is_completed true
    execute(
      "UPDATE subtasks SET is_completed = true WHERE status = 'done'",
      "UPDATE subtasks SET status = 'done' WHERE is_completed = true"
    )

    alter table(:subtasks) do
      remove(:status, :string, default: "todo")
    end
  end
end
