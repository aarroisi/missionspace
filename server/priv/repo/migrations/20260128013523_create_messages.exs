defmodule Missionspace.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:text, :text, null: false)
      add(:entity_type, :string, null: false)
      add(:entity_id, :binary_id, null: false)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:parent_id, references(:messages, type: :binary_id, on_delete: :delete_all))
      add(:quote_id, references(:messages, type: :binary_id, on_delete: :nilify_all))

      timestamps(type: :timestamptz)
    end

    create(index(:messages, [:entity_type, :entity_id]))
    create(index(:messages, [:user_id]))
    create(index(:messages, [:parent_id]))
    create(index(:messages, [:quote_id]))
  end
end
