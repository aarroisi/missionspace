defmodule Missionspace.Repo.Migrations.AddDueOnToSubtasks do
  use Ecto.Migration

  def change do
    alter table(:subtasks) do
      add(:due_on, :date)
    end
  end
end
