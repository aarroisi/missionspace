defmodule Missionspace.Repo.Migrations.CreateListStatuses do
  use Ecto.Migration

  def up do
    # Create list_statuses table
    create table(:list_statuses, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:color, :string, null: false, default: "#6b7280")
      add(:position, :integer, null: false, default: 0)
      add(:list_id, references(:lists, type: :binary_id, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:list_statuses, [:list_id, :position]))
    create(unique_index(:list_statuses, [:list_id, :name]))

    # Add status_id to tasks
    alter table(:tasks) do
      add(:status_id, references(:list_statuses, type: :binary_id, on_delete: :nilify_all))
    end

    create(index(:tasks, [:status_id]))

    # Seed default statuses for existing lists and migrate tasks
    execute("""
    INSERT INTO list_statuses (id, name, color, position, list_id, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      s.status_name,
      CASE s.status_name
        WHEN 'todo' THEN '#6b7280'
        WHEN 'doing' THEN '#3b82f6'
        WHEN 'done' THEN '#22c55e'
      END,
      CASE s.status_name
        WHEN 'todo' THEN 0
        WHEN 'doing' THEN 1
        WHEN 'done' THEN 2
      END,
      l.id,
      NOW(),
      NOW()
    FROM lists l
    CROSS JOIN (VALUES ('todo'), ('doing'), ('done')) AS s(status_name)
    """)

    # Migrate existing tasks to use status_id
    execute("""
    UPDATE tasks t
    SET status_id = ls.id
    FROM list_statuses ls
    WHERE t.list_id = ls.list_id AND t.status = ls.name
    """)

    # Remove old status column
    alter table(:tasks) do
      remove(:status)
    end
  end

  def down do
    # Add back the status column
    alter table(:tasks) do
      add(:status, :string, default: "todo")
    end

    # Migrate status_id back to status string
    execute("""
    UPDATE tasks t
    SET status = ls.name
    FROM list_statuses ls
    WHERE t.status_id = ls.id
    """)

    # Remove status_id
    drop(index(:tasks, [:status_id]))

    alter table(:tasks) do
      remove(:status_id)
    end

    # Drop list_statuses table
    drop(index(:list_statuses, [:list_id, :name]))
    drop(index(:list_statuses, [:list_id, :position]))
    drop(table(:list_statuses))
  end
end
