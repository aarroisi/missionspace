defmodule Missionspace.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:actor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:type, :string, null: false)
      add(:entity_type, :string, null: false)
      add(:entity_id, :binary_id, null: false)
      add(:context, :map, default: %{})
      add(:read, :boolean, default: false, null: false)

      timestamps(type: :timestamptz)
    end

    create(index(:notifications, [:user_id]))
    create(index(:notifications, [:actor_id]))
    create(index(:notifications, [:user_id, :read]))
    create(index(:notifications, [:entity_type, :entity_id]))
  end
end
