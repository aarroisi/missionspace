defmodule Missionspace.Repo.Migrations.UpdateNotificationsForRollup do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add(:item_type, :string)
      add(:item_id, :binary_id)
      add(:thread_id, :binary_id)
      add(:latest_message_id, :binary_id)
      add(:event_count, :integer, default: 1, null: false)
    end

    # Null-safe unique index for rollup: COALESCE thread_id to a zero UUID for null values
    create(
      unique_index(
        :notifications,
        [
          :user_id,
          :type,
          :item_type,
          :item_id,
          "COALESCE(thread_id, '00000000-0000-0000-0000-000000000000')"
        ],
        name: :notifications_rollup_unique_idx
      )
    )

    create(index(:notifications, [:item_type, :item_id]))
  end
end
