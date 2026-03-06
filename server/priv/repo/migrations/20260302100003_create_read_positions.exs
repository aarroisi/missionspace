defmodule Missionspace.Repo.Migrations.CreateReadPositions do
  use Ecto.Migration

  def change do
    create table(:read_positions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:item_type, :string, null: false)
      add(:item_id, :binary_id, null: false)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:last_read_at, :timestamptz, null: false)

      timestamps(type: :timestamptz)
    end

    create(unique_index(:read_positions, [:item_type, :item_id, :user_id]))
    create(index(:read_positions, [:user_id]))
  end
end
