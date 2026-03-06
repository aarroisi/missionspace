defmodule Missionspace.Repo.Migrations.AddVisibilityToItems do
  use Ecto.Migration

  def up do
    alter table(:lists) do
      add :visibility, :string, null: false, default: "shared"
    end

    alter table(:doc_folders) do
      add :visibility, :string, null: false, default: "shared"
    end

    alter table(:channels) do
      add :visibility, :string, null: false, default: "shared"
    end

    create index(:lists, [:workspace_id, :visibility])
    create index(:doc_folders, [:workspace_id, :visibility])
    create index(:channels, [:workspace_id, :visibility])
  end

  def down do
    drop index(:lists, [:workspace_id, :visibility])
    drop index(:doc_folders, [:workspace_id, :visibility])
    drop index(:channels, [:workspace_id, :visibility])

    alter table(:lists) do
      remove :visibility
    end

    alter table(:doc_folders) do
      remove :visibility
    end

    alter table(:channels) do
      remove :visibility
    end
  end
end
