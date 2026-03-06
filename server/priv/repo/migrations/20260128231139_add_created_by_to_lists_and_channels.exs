defmodule Missionspace.Repo.Migrations.AddCreatedByToListsAndChannels do
  use Ecto.Migration

  def change do
    alter table(:lists) do
      add(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    alter table(:channels) do
      add(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end
  end
end
