defmodule Bridge.Lists.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "tasks" do
    field(:title, :string)
    field(:sequence_number, :integer)
    field(:position, :integer, default: 0)
    field(:is_completed, :boolean, default: false)
    field(:starred, :boolean, virtual: true, default: false)
    field(:notes, :string)
    field(:due_on, :date)
    field(:completed_at, :utc_datetime_usec)
    field(:comment_count, :integer, virtual: true, default: 0)
    field(:child_count, :integer, virtual: true, default: 0)
    field(:child_done_count, :integer, virtual: true, default: 0)

    belongs_to(:list, Bridge.Lists.List)
    belongs_to(:status, Bridge.Lists.ListStatus)
    belongs_to(:parent, Bridge.Lists.Task)
    belongs_to(:assignee, Bridge.Accounts.User)
    belongs_to(:created_by, Bridge.Accounts.User)

    has_many(:children, Bridge.Lists.Task, foreign_key: :parent_id)

    timestamps()
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :title,
      :sequence_number,
      :position,
      :is_completed,
      :notes,
      :due_on,
      :completed_at,
      :list_id,
      :status_id,
      :parent_id,
      :assignee_id,
      :created_by_id
    ])
    |> validate_required([:title, :list_id, :created_by_id])
    |> foreign_key_constraint(:status_id)
    |> foreign_key_constraint(:parent_id)
  end
end
