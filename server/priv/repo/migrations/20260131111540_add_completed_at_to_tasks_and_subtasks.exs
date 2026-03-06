defmodule Missionspace.Repo.Migrations.AddCompletedAtToTasksAndSubtasks do
  use Ecto.Migration

  def change do
    # Add completed_at to tasks
    alter table(:tasks) do
      add(:completed_at, :utc_datetime_usec)
    end

    # Add completed_at to subtasks
    alter table(:subtasks) do
      add(:completed_at, :utc_datetime_usec)
    end

    # Add is_done to list_statuses to mark which status represents "done"
    alter table(:list_statuses) do
      add(:is_done, :boolean, default: false, null: false)
    end

    # Create index for faster queries on completed tasks
    create(index(:tasks, [:completed_at]))
    create(index(:subtasks, [:completed_at]))
  end
end
