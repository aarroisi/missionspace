defmodule Bridge.Repo.Migrations.CreateDocFoldersAndSharedPrefixes do
  use Ecto.Migration

  def up do
    # Step 1: Create shared prefixes table
    create table(:prefixes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :prefix, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :binary_id, null: false

      add :workspace_id,
          references(:workspaces, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:prefixes, [:workspace_id, :prefix])
    create index(:prefixes, [:entity_type, :entity_id])

    # Step 2: Create doc_folders table
    create table(:doc_folders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :prefix, :string, null: false
      add :doc_sequence_counter, :integer, null: false, default: 0
      add :starred, :boolean, null: false, default: false

      add :workspace_id,
          references(:workspaces, type: :binary_id, on_delete: :delete_all),
          null: false

      add :created_by_id,
          references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:doc_folders, [:workspace_id])
    create unique_index(:doc_folders, [:workspace_id, :prefix])

    # Step 3: Add doc_folder_id and sequence_number to docs (nullable initially)
    alter table(:docs) do
      add :doc_folder_id,
          references(:doc_folders, type: :binary_id, on_delete: :delete_all)

      add :sequence_number, :integer
    end

    create index(:docs, [:doc_folder_id])

    # Step 4: Backfill existing board prefixes into prefixes table
    execute """
    INSERT INTO prefixes (id, prefix, entity_type, entity_id, workspace_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), l.prefix, 'list', l.id, l.workspace_id, NOW(), NOW()
    FROM lists l
    WHERE l.prefix IS NOT NULL
    """

    # Step 5: Delete orphaned docs with no workspace_id
    execute "DELETE FROM docs WHERE workspace_id IS NULL"

    # Step 6: Create doc folders for existing docs and assign them
    # This uses PL/pgSQL to handle prefix collision avoidance
    execute """
    DO $$
    DECLARE
      ws RECORD;
      folder_id UUID;
      chosen_prefix TEXT;
      candidate TEXT;
      i INT;
    BEGIN
      -- For each workspace that has docs
      FOR ws IN SELECT DISTINCT workspace_id FROM docs WHERE workspace_id IS NOT NULL LOOP
        -- Find an available prefix starting with 'DN'
        chosen_prefix := NULL;

        -- Try candidates: DN, DO, DC, DX, DN2, DN3, ...
        FOR candidate IN
          SELECT unnest(ARRAY['DN', 'DO', 'DC', 'DX', 'DM', 'DD'])
        LOOP
          IF NOT EXISTS (
            SELECT 1 FROM prefixes
            WHERE workspace_id = ws.workspace_id AND prefix = candidate
          ) THEN
            chosen_prefix := candidate;
            EXIT;
          END IF;
        END LOOP;

        -- If still not found, try numeric suffixes
        IF chosen_prefix IS NULL THEN
          FOR i IN 2..99 LOOP
            candidate := 'DN' || i::TEXT;
            IF LENGTH(candidate) <= 5 AND NOT EXISTS (
              SELECT 1 FROM prefixes
              WHERE workspace_id = ws.workspace_id AND prefix = candidate
            ) THEN
              chosen_prefix := candidate;
              EXIT;
            END IF;
          END LOOP;
        END IF;

        -- Fallback
        IF chosen_prefix IS NULL THEN
          chosen_prefix := 'DOCXX';
        END IF;

        -- Create the doc folder
        folder_id := gen_random_uuid();

        INSERT INTO doc_folders (id, name, prefix, doc_sequence_counter, starred, workspace_id, created_by_id, inserted_at, updated_at)
        VALUES (
          folder_id,
          'Documents',
          chosen_prefix,
          (SELECT COUNT(*) FROM docs WHERE docs.workspace_id = ws.workspace_id),
          false,
          ws.workspace_id,
          (SELECT docs.author_id FROM docs WHERE docs.workspace_id = ws.workspace_id ORDER BY docs.inserted_at ASC LIMIT 1),
          NOW(),
          NOW()
        );

        -- Register the prefix
        INSERT INTO prefixes (id, prefix, entity_type, entity_id, workspace_id, inserted_at, updated_at)
        VALUES (gen_random_uuid(), chosen_prefix, 'doc_folder', folder_id, ws.workspace_id, NOW(), NOW());

        -- Assign docs to the folder with sequence numbers
        WITH numbered AS (
          SELECT d.id, ROW_NUMBER() OVER (ORDER BY d.inserted_at ASC) AS rn
          FROM docs d
          WHERE d.workspace_id = ws.workspace_id
        )
        UPDATE docs
        SET doc_folder_id = folder_id, sequence_number = numbered.rn
        FROM numbered
        WHERE docs.id = numbered.id;
      END LOOP;
    END $$;
    """

    # Step 7: Migrate project_items from doc -> doc_folder
    # Insert distinct doc_folder project_items, then delete old doc ones
    execute """
    INSERT INTO project_items (id, project_id, item_type, item_id, inserted_at, updated_at)
    SELECT DISTINCT ON (pi.project_id, d.doc_folder_id)
      gen_random_uuid(), pi.project_id, 'doc_folder', d.doc_folder_id, pi.inserted_at, pi.updated_at
    FROM project_items pi
    JOIN docs d ON d.id = pi.item_id
    WHERE pi.item_type = 'doc'
    ON CONFLICT (item_type, item_id) DO NOTHING
    """

    execute "DELETE FROM project_items WHERE item_type = 'doc'"

    # Step 8: Add NOT NULL constraints
    alter table(:docs) do
      modify :doc_folder_id, :binary_id, null: false
      modify :sequence_number, :integer, null: false
    end

    create unique_index(:docs, [:doc_folder_id, :sequence_number])
  end

  def down do
    # Restore project_items from doc_folder -> doc (best effort: link to first doc in folder)
    execute """
    INSERT INTO project_items (id, project_id, item_type, item_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), pi.project_id, 'doc', d.id, NOW(), NOW()
    FROM project_items pi
    JOIN docs d ON d.doc_folder_id = pi.item_id
    WHERE pi.item_type = 'doc_folder'
    ON CONFLICT DO NOTHING
    """

    execute "DELETE FROM project_items WHERE item_type = 'doc_folder'"

    drop_if_exists unique_index(:docs, [:doc_folder_id, :sequence_number])

    alter table(:docs) do
      remove :doc_folder_id
      remove :sequence_number
    end

    drop_if_exists table(:doc_folders)
    drop_if_exists table(:prefixes)
  end
end
