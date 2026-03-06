defmodule Missionspace.Repo.Migrations.UppercaseStatusNames do
  use Ecto.Migration

  def up do
    execute("UPDATE list_statuses SET name = UPPER(name)")
  end

  def down do
    # No-op: we don't want to lowercase names on rollback
    :ok
  end
end
