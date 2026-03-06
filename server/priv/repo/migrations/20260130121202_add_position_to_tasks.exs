defmodule Missionspace.Repo.Migrations.AddPositionToTasks do
  use Ecto.Migration

  def up do
    alter table(:tasks) do
      add(:position, :integer, default: 0, null: false)
    end

    # Composite index for efficient ordering within list+status
    create(index(:tasks, [:list_id, :status, :position]))

    # Backfill existing tasks with positions using gaps of 1000
    execute("""
    WITH ranked AS (
      SELECT id, ROW_NUMBER() OVER (
        PARTITION BY list_id, status
        ORDER BY id
      ) * 1000 as new_position
      FROM tasks
    )
    UPDATE tasks SET position = ranked.new_position
    FROM ranked WHERE tasks.id = ranked.id
    """)
  end

  def down do
    drop(index(:tasks, [:list_id, :status, :position]))

    alter table(:tasks) do
      remove(:position)
    end
  end
end
