defmodule Missionspace.Repo.Migrations.AddBoardPrefixAndTaskSequence do
  use Ecto.Migration

  def up do
    # Step 1: Add columns (nullable initially for backfill)
    alter table(:lists) do
      add :prefix, :string
      add :task_sequence_counter, :integer, null: false, default: 0
    end

    alter table(:tasks) do
      add :sequence_number, :integer
    end

    flush()

    # Step 2: Backfill prefixes for existing boards
    execute("""
    DO $$
    DECLARE
      board RECORD;
      candidate TEXT;
      prefix_length INT;
      suffix INT;
      base TEXT;
      taken BOOLEAN;
    BEGIN
      FOR board IN
        SELECT id, name, workspace_id FROM lists ORDER BY inserted_at ASC
      LOOP
        base := upper(regexp_replace(board.name, '[^a-zA-Z]', '', 'g'));
        IF length(base) < 2 THEN
          base := rpad(base, 2, 'X');
        END IF;

        taken := true;
        FOR prefix_length IN 2..LEAST(5, length(base)) LOOP
          candidate := left(base, prefix_length);
          SELECT EXISTS(
            SELECT 1 FROM lists
            WHERE workspace_id = board.workspace_id
              AND prefix = candidate
              AND id != board.id
          ) INTO taken;
          IF NOT taken THEN
            EXIT;
          END IF;
        END LOOP;

        IF taken THEN
          suffix := 2;
          LOOP
            candidate := left(base, 2) || suffix::text;
            SELECT EXISTS(
              SELECT 1 FROM lists
              WHERE workspace_id = board.workspace_id
                AND prefix = candidate
                AND id != board.id
            ) INTO taken;
            EXIT WHEN NOT taken;
            suffix := suffix + 1;
          END LOOP;
        END IF;

        UPDATE lists SET prefix = candidate WHERE id = board.id;
      END LOOP;
    END $$;
    """)

    # Step 3: Backfill sequence numbers for existing tasks
    execute("""
    WITH numbered AS (
      SELECT id, list_id,
        ROW_NUMBER() OVER (PARTITION BY list_id ORDER BY inserted_at ASC) as rn
      FROM tasks
    )
    UPDATE tasks t
    SET sequence_number = n.rn
    FROM numbered n
    WHERE t.id = n.id;
    """)

    # Step 4: Set each board's counter to its max sequence number
    execute("""
    UPDATE lists l
    SET task_sequence_counter = COALESCE(
      (SELECT MAX(sequence_number) FROM tasks WHERE list_id = l.id),
      0
    );
    """)

    # Step 5: Add NOT NULL constraints
    alter table(:lists) do
      modify :prefix, :string, null: false
    end

    alter table(:tasks) do
      modify :sequence_number, :integer, null: false
    end

    # Step 6: Add unique indexes
    create unique_index(:lists, [:workspace_id, :prefix])
    create unique_index(:tasks, [:list_id, :sequence_number])
  end

  def down do
    drop_if_exists index(:tasks, [:list_id, :sequence_number])
    drop_if_exists index(:lists, [:workspace_id, :prefix])

    alter table(:tasks) do
      remove :sequence_number
    end

    alter table(:lists) do
      remove :prefix
      remove :task_sequence_counter
    end
  end
end
