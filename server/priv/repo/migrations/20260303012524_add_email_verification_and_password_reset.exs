defmodule Missionspace.Repo.Migrations.AddEmailVerificationAndPasswordReset do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_verified_at, :utc_datetime_usec
      add :email_verification_token, :string
      add :password_reset_token, :string
      add :password_reset_expires_at, :utc_datetime_usec
    end

    create index(:users, [:email_verification_token], unique: true)
    create index(:users, [:password_reset_token], unique: true)

    # Backfill existing users so they aren't locked out
    execute "UPDATE users SET email_verified_at = NOW() WHERE email_verified_at IS NULL",
            "SELECT 1"
  end
end
