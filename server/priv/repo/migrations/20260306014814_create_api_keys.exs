defmodule Missionspace.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:key_hash, :string, null: false)
      add(:key_prefix, :string, null: false)
      add(:scopes, {:array, :string}, null: false, default: [])
      add(:last_used_at, :utc_datetime_usec)
      add(:revoked_at, :utc_datetime_usec)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:api_keys, [:user_id]))
    create(index(:api_keys, [:user_id, :revoked_at]))
    create(unique_index(:api_keys, [:key_hash]))
  end
end
