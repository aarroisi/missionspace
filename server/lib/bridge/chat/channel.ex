defmodule Bridge.Chat.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "channels" do
    field(:name, :string)
    field(:visibility, :string, default: "shared")
    field(:starred, :boolean, virtual: true, default: false)

    belongs_to(:workspace, Bridge.Accounts.Workspace)
    belongs_to(:created_by, Bridge.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :workspace_id, :created_by_id, :visibility])
    |> validate_required([:name, :workspace_id])
    |> validate_inclusion(:visibility, ["private", "shared"])
    |> unique_constraint([:workspace_id, :name],
      message: "a channel with this name already exists"
    )
  end
end
