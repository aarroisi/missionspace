defmodule Missionspace.Lists.ListStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "list_statuses" do
    field(:name, :string)
    field(:color, :string, default: "#6b7280")
    field(:position, :integer, default: 0)
    field(:is_done, :boolean, default: false)

    belongs_to(:list, Missionspace.Lists.List)
    has_many(:tasks, Missionspace.Lists.Task, foreign_key: :status_id)

    timestamps()
  end

  @doc false
  def changeset(status, attrs) do
    status
    |> cast(attrs, [:name, :color, :position, :list_id, :is_done])
    |> validate_required([:name, :list_id])
    |> uppercase_name()
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color")
    |> unique_constraint([:list_id, :name],
      name: :list_statuses_list_id_name_index,
      message: "already exists in this list"
    )
  end

  defp uppercase_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, String.upcase(name))
    end
  end
end
