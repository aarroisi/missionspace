defmodule Missionspace.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table(:assets, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:uploaded_by_id, references(:users, type: :binary_id, on_delete: :restrict),
        null: false
      )

      add(:filename, :string, null: false)
      add(:content_type, :string, null: false)
      add(:size_bytes, :bigint, null: false)
      add(:storage_key, :string, null: false)
      add(:asset_type, :string, null: false)
      add(:status, :string, null: false, default: "pending")

      timestamps(type: :timestamptz)
    end

    create(index(:assets, [:workspace_id]))
    create(index(:assets, [:uploaded_by_id]))
    create(unique_index(:assets, [:storage_key]))
    create(index(:assets, [:workspace_id, :asset_type]))
    create(index(:assets, [:workspace_id, :status]))
  end
end
