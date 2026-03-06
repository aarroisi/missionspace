defmodule Missionspace.Repo.Migrations.AddAttachableToAssets do
  use Ecto.Migration

  def change do
    alter table(:assets) do
      # Polymorphic association to track which item the asset is attached to
      # attachable_type: "doc", "message", "user" (for avatars), etc.
      # attachable_id: the UUID of the item
      add(:attachable_type, :string)
      add(:attachable_id, :uuid)
    end

    # Index for efficient lookups of all assets for an item
    create(index(:assets, [:attachable_type, :attachable_id]))
  end
end
