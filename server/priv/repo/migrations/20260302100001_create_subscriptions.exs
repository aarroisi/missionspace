defmodule Bridge.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:item_type, :string, null: false)
      add(:item_id, :binary_id, null: false)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)

      add(
        :workspace_id,
        references(:workspaces, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      timestamps(type: :timestamptz)
    end

    create(unique_index(:subscriptions, [:item_type, :item_id, :user_id]))
    create(index(:subscriptions, [:user_id]))
    create(index(:subscriptions, [:workspace_id]))
    create(index(:subscriptions, [:item_type, :item_id]))
  end
end
