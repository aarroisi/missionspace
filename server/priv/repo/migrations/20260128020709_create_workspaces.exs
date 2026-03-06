defmodule Missionspace.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:slug, :string, null: false)

      timestamps(type: :timestamptz)
    end

    create(unique_index(:workspaces, [:slug]))

    # Add workspace_id to users
    alter table(:users) do
      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all))
      add(:password_hash, :string)
    end

    create(index(:users, [:workspace_id]))
  end
end
