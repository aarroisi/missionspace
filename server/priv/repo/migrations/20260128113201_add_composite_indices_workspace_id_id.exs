defmodule Missionspace.Repo.Migrations.AddCompositeIndicesWorkspaceIdId do
  use Ecto.Migration

  def change do
    # Add composite indices (workspace_id, id) for efficient sorting by UUIDv7 chronological order
    # These indices support queries that filter by workspace_id and sort by id
    # We keep the existing single-column workspace_id indices for other query patterns
    create(index(:docs, [:workspace_id, :id]))
    create(index(:lists, [:workspace_id, :id]))
    create(index(:projects, [:workspace_id, :id]))
    create(index(:channels, [:workspace_id, :id]))
    create(index(:direct_messages, [:workspace_id, :id]))
  end
end
