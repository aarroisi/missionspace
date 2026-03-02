defmodule Bridge.Repo.Migrations.AddSearchTrigramIndexes do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # Projects
    execute "CREATE INDEX projects_name_trgm ON projects USING GIN (name gin_trgm_ops)"

    # Boards (lists)
    execute "CREATE INDEX lists_name_trgm ON lists USING GIN (name gin_trgm_ops)"
    execute "CREATE INDEX lists_prefix_trgm ON lists USING GIN (prefix gin_trgm_ops)"

    # Tasks
    execute "CREATE INDEX tasks_title_trgm ON tasks USING GIN (title gin_trgm_ops)"

    # Doc folders
    execute "CREATE INDEX doc_folders_name_trgm ON doc_folders USING GIN (name gin_trgm_ops)"
    execute "CREATE INDEX doc_folders_prefix_trgm ON doc_folders USING GIN (prefix gin_trgm_ops)"

    # Docs
    execute "CREATE INDEX docs_title_trgm ON docs USING GIN (title gin_trgm_ops)"

    # Channels
    execute "CREATE INDEX channels_name_trgm ON channels USING GIN (name gin_trgm_ops)"

    # Users (members)
    execute "CREATE INDEX users_name_trgm ON users USING GIN (name gin_trgm_ops)"
    execute "CREATE INDEX users_email_trgm ON users USING GIN (email gin_trgm_ops)"
  end

  def down do
    execute "DROP INDEX IF EXISTS projects_name_trgm"
    execute "DROP INDEX IF EXISTS lists_name_trgm"
    execute "DROP INDEX IF EXISTS lists_prefix_trgm"
    execute "DROP INDEX IF EXISTS tasks_title_trgm"
    execute "DROP INDEX IF EXISTS doc_folders_name_trgm"
    execute "DROP INDEX IF EXISTS doc_folders_prefix_trgm"
    execute "DROP INDEX IF EXISTS docs_title_trgm"
    execute "DROP INDEX IF EXISTS channels_name_trgm"
    execute "DROP INDEX IF EXISTS users_name_trgm"
    execute "DROP INDEX IF EXISTS users_email_trgm"
    execute "DROP EXTENSION IF EXISTS pg_trgm"
  end
end
