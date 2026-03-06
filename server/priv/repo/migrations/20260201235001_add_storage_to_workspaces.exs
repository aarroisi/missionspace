defmodule Missionspace.Repo.Migrations.AddStorageToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add(:storage_used_bytes, :bigint, null: false, default: 0)
      # 5 GB
      add(:storage_quota_bytes, :bigint, null: false, default: 5_368_709_120)
    end
  end
end
