defmodule Missionspace.Repo.Migrations.CreateDeviceSessions do
  use Ecto.Migration

  def change do
    create table(:device_sessions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:token_hash, :string, null: false)
      add(:last_seen_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:device_sessions, [:token_hash]))

    create table(:device_session_accounts, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:session_token_hash, :string)
      add(:session_token_expires_at, :utc_datetime_usec)
      add(:signed_out_at, :utc_datetime_usec)
      add(:last_used_at, :utc_datetime_usec)
      add(:last_authenticated_at, :utc_datetime_usec)

      add(
        :device_session_id,
        references(:device_sessions, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:device_session_accounts, [:device_session_id]))
    create(index(:device_session_accounts, [:user_id]))
    create(index(:device_session_accounts, [:session_token_expires_at]))
    create(unique_index(:device_session_accounts, [:device_session_id, :user_id]))
  end
end
