defmodule Bridge.Repo.Migrations.MakeNotificationEntityFieldsNullable do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      modify(:entity_type, :string, null: true, from: {:string, null: false})
      modify(:entity_id, :binary_id, null: true, from: {:binary_id, null: false})
    end
  end
end
