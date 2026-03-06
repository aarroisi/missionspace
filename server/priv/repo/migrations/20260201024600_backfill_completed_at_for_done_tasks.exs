defmodule Missionspace.Repo.Migrations.BackfillCompletedAtForDoneTasks do
  use Ecto.Migration

  def up do
    # Set completed_at to updated_at for tasks in DONE status that don't have completed_at
    execute("""
    UPDATE tasks
    SET completed_at = tasks.updated_at
    FROM list_statuses
    WHERE tasks.status_id = list_statuses.id
      AND list_statuses.is_done = true
      AND tasks.completed_at IS NULL
    """)

    # Set completed_at to updated_at for subtasks with status 'done' that don't have completed_at
    execute("""
    UPDATE subtasks
    SET completed_at = updated_at
    WHERE status = 'done'
      AND completed_at IS NULL
    """)
  end

  def down do
    # We can't reliably revert this since we don't know which tasks had NULL before
    :ok
  end
end
