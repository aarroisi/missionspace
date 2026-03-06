defmodule Missionspace.Repo.Migrations.CreateUserStarsTable do
  use Ecto.Migration

  def change do
    create table(:user_stars, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :starrable_type, :string, null: false
      add :starrable_id, :binary_id, null: false
      timestamps()
    end

    create unique_index(:user_stars, [:user_id, :starrable_type, :starrable_id])
    create index(:user_stars, [:starrable_type, :starrable_id])

    # Remove starred columns from all entities
    alter table(:projects) do
      remove :starred, :boolean, default: false
    end

    alter table(:lists) do
      remove :starred, :boolean, default: false
    end

    alter table(:doc_folders) do
      remove :starred, :boolean, default: false
    end

    alter table(:docs) do
      remove :starred, :boolean, default: false
    end

    alter table(:channels) do
      remove :starred, :boolean, default: false
    end

    alter table(:direct_messages) do
      remove :starred, :boolean, default: false
    end

    alter table(:tasks) do
      remove :starred, :boolean, default: false
    end
  end
end
