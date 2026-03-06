defmodule Missionspace.Repo.Migrations.AddWorkspaceIdToAllItems do
  use Ecto.Migration

  def change do
    # Add workspace_id to docs
    alter table(:docs) do
      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all))
    end

    create(index(:docs, [:workspace_id]))

    # Add workspace_id to lists
    alter table(:lists) do
      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all))
    end

    create(index(:lists, [:workspace_id]))

    # Add workspace_id to projects
    alter table(:projects) do
      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all))
    end

    create(index(:projects, [:workspace_id]))

    # Add workspace_id to channels
    alter table(:channels) do
      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all))
    end

    create(index(:channels, [:workspace_id]))

    # Add workspace_id to direct_messages
    alter table(:direct_messages) do
      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all))
    end

    create(index(:direct_messages, [:workspace_id]))
  end
end
