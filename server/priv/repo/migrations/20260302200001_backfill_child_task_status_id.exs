defmodule Bridge.Repo.Migrations.BackfillChildTaskStatusId do
  use Ecto.Migration

  def up do
    # Set child tasks with is_completed=true to their board's done status
    execute """
    UPDATE tasks
    SET status_id = (
      SELECT ls.id FROM list_statuses ls
      WHERE ls.list_id = tasks.list_id AND ls.is_done = true
      ORDER BY ls.position ASC LIMIT 1
    )
    WHERE tasks.parent_id IS NOT NULL
      AND tasks.status_id IS NULL
      AND tasks.is_completed = true
    """

    # Set remaining child tasks (not completed) to their board's first status
    execute """
    UPDATE tasks
    SET status_id = (
      SELECT ls.id FROM list_statuses ls
      WHERE ls.list_id = tasks.list_id
      ORDER BY ls.position ASC LIMIT 1
    )
    WHERE tasks.parent_id IS NOT NULL
      AND tasks.status_id IS NULL
    """
  end

  def down do
    execute """
    UPDATE tasks
    SET status_id = NULL
    WHERE tasks.parent_id IS NOT NULL
    """
  end
end
