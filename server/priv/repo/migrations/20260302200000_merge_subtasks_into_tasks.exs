defmodule Missionspace.Repo.Migrations.MergeSubtasksIntoTasks do
  use Ecto.Migration

  def up do
    # Step 1: Add new columns to tasks table
    alter table(:tasks) do
      add :parent_id, references(:tasks, type: :uuid, on_delete: :delete_all), null: true
      add :is_completed, :boolean, null: false, default: false
    end

    create index(:tasks, [:parent_id])

    # Step 2: Migrate subtask data into tasks
    # For each subtask, create a task with parent_id pointing to the original task
    execute """
    DO $$
    DECLARE
      rec RECORD;
      new_task_id uuid;
      new_seq integer;
      parent_list_id uuid;
      parent_workspace_id uuid;
    BEGIN
      FOR rec IN SELECT * FROM subtasks ORDER BY inserted_at ASC LOOP
        -- Get parent task's list_id and workspace_id
        SELECT t.list_id, l.workspace_id
        INTO parent_list_id, parent_workspace_id
        FROM tasks t
        JOIN lists l ON l.id = t.list_id
        WHERE t.id = rec.task_id;

        -- Skip if parent task doesn't exist
        IF parent_list_id IS NULL THEN
          CONTINUE;
        END IF;

        -- Atomically increment the board's sequence counter
        UPDATE lists
        SET task_sequence_counter = task_sequence_counter + 1
        WHERE id = parent_list_id
        RETURNING task_sequence_counter INTO new_seq;

        -- Generate a new UUIDv7 for the task
        new_task_id := gen_random_uuid();

        -- Insert the subtask as a task
        INSERT INTO tasks (id, title, notes, due_on, completed_at, is_completed,
                          list_id, parent_id, assignee_id, created_by_id,
                          sequence_number, position, status_id,
                          inserted_at, updated_at)
        VALUES (new_task_id, rec.title, rec.notes, rec.due_on, rec.completed_at,
                COALESCE(rec.is_completed, false),
                parent_list_id, rec.task_id, rec.assignee_id, rec.created_by_id,
                new_seq, 0, NULL,
                rec.inserted_at, rec.updated_at);

        -- Update messages that reference this subtask
        UPDATE messages
        SET entity_type = 'task', entity_id = new_task_id
        WHERE entity_type = 'subtask' AND entity_id = rec.id;

        -- Update notifications that reference this subtask
        UPDATE notifications
        SET entity_type = 'task', entity_id = new_task_id,
            context = jsonb_set(
              jsonb_set(
                context::jsonb - 'subtaskId' - 'subtaskTitle',
                '{taskId}', to_jsonb(new_task_id::text)
              ),
              '{taskTitle}', to_jsonb(rec.title)
            )
        WHERE entity_type = 'subtask' AND entity_id = rec.id;

        -- Update assets that reference this subtask
        UPDATE assets
        SET attachable_type = 'task', attachable_id = new_task_id
        WHERE attachable_type = 'subtask' AND attachable_id = rec.id;
      END LOOP;
    END $$;
    """

    # Step 3: Drop the subtasks table
    drop table(:subtasks)
  end

  def down do
    # Recreate subtasks table
    create table(:subtasks, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, null: false
      add :is_completed, :boolean, default: false
      add :notes, :text
      add :due_on, :date
      add :completed_at, :utc_datetime_usec

      add :task_id, references(:tasks, type: :uuid, on_delete: :delete_all), null: false
      add :assignee_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :created_by_id, references(:users, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:subtasks, [:task_id])

    # Remove new columns from tasks
    drop index(:tasks, [:parent_id])

    alter table(:tasks) do
      remove :parent_id
      remove :is_completed
    end
  end
end
