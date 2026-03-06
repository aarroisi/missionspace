defmodule Missionspace.Repo.Migrations.CreateProjectItems do
  use Ecto.Migration

  def change do
    create table(:project_items, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      # "list", "doc", "channel"
      add(:item_type, :string, null: false)
      add(:item_id, :binary_id, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    # Ensure each item can only be in one project
    create(unique_index(:project_items, [:item_type, :item_id], name: :project_items_unique_item))
    # Index for querying items by project
    create(index(:project_items, [:project_id]))
  end
end
