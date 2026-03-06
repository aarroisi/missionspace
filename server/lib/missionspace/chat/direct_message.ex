defmodule Missionspace.Chat.DirectMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "direct_messages" do
    field(:starred, :boolean, virtual: true, default: false)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)
    belongs_to(:user1, Missionspace.Accounts.User)
    belongs_to(:user2, Missionspace.Accounts.User)

    timestamps()
  end

  @doc false
  def changeset(direct_message, attrs) do
    direct_message
    |> cast(attrs, [:workspace_id, :user1_id, :user2_id])
    |> validate_required([:workspace_id, :user1_id, :user2_id])
    |> unique_constraint([:user1_id, :user2_id])
  end
end
