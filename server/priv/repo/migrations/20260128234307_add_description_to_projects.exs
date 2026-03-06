defmodule Missionspace.Repo.Migrations.AddDescriptionToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add(:description, :text)
    end
  end
end
