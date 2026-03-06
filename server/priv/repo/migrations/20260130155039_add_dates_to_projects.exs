defmodule Missionspace.Repo.Migrations.AddDatesToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add(:start_date, :date)
      add(:end_date, :date)
    end
  end
end
