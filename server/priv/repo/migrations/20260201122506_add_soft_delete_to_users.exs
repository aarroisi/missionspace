defmodule Missionspace.Repo.Migrations.AddSoftDeleteToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:is_active, :boolean, default: true, null: false)
      add(:deleted_at, :utc_datetime_usec)
    end

    create(index(:users, [:is_active]))
  end
end
