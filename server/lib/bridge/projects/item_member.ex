defmodule Bridge.Projects.ItemMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_item_types ["list", "doc_folder", "channel"]

  schema "item_members" do
    field(:item_type, :string)
    field(:item_id, Ecto.UUID)

    belongs_to(:user, Bridge.Accounts.User)
    belongs_to(:workspace, Bridge.Accounts.Workspace)

    timestamps()
  end

  @doc false
  def changeset(item_member, attrs) do
    item_member
    |> cast(attrs, [:item_type, :item_id, :user_id, :workspace_id])
    |> validate_required([:item_type, :item_id, :user_id, :workspace_id])
    |> validate_inclusion(:item_type, @valid_item_types)
    |> unique_constraint([:item_type, :item_id, :user_id],
      message: "user is already a member of this item"
    )
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:workspace_id)
  end
end
