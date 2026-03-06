defmodule Missionspace.Repo.Migrations.BackfillProjectsCreatedBy do
  use Ecto.Migration

  def up do
    # Set created_by_id to the owner of the workspace for all projects
    execute("""
    UPDATE projects
    SET created_by_id = (
      SELECT u.id FROM users u
      WHERE u.workspace_id = projects.workspace_id
      AND u.role = 'owner'
      LIMIT 1
    )
    WHERE created_by_id IS NULL
    """)
  end

  def down do
    execute("UPDATE projects SET created_by_id = NULL")
  end
end
