defmodule Bridge.Stars.UserStar do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "user_stars" do
    belongs_to(:user, Bridge.Accounts.User)
    field(:starrable_type, :string)
    field(:starrable_id, Ecto.UUID)

    timestamps()
  end

  def changeset(star, attrs) do
    star
    |> cast(attrs, [:user_id, :starrable_type, :starrable_id])
    |> validate_required([:user_id, :starrable_type, :starrable_id])
    |> validate_inclusion(:starrable_type, ~w(project board doc_folder doc channel direct_message task))
    |> unique_constraint([:user_id, :starrable_type, :starrable_id])
  end
end
