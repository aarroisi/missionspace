defmodule Missionspace.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:email, :string, null: false)
      add(:avatar, :string)
      add(:online, :boolean, default: false, null: false)

      timestamps(type: :timestamptz)
    end

    create(unique_index(:users, [:email]))
  end
end
