defmodule Missionspace.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:role, :string, null: false, default: "owner")
    end

    create(constraint(:users, :valid_role, check: "role IN ('owner', 'member', 'guest')"))
  end
end
