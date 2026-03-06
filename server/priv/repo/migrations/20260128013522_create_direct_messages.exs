defmodule Missionspace.Repo.Migrations.CreateDirectMessages do
  use Ecto.Migration

  def change do
    create table(:direct_messages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:starred, :boolean, default: false, null: false)
      add(:user1_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:user2_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)

      timestamps(type: :timestamptz)
    end

    create(index(:direct_messages, [:user1_id]))
    create(index(:direct_messages, [:user2_id]))
    create(unique_index(:direct_messages, [:user1_id, :user2_id]))
  end
end
