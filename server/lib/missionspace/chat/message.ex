defmodule Missionspace.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]
  schema "messages" do
    field(:text, :string)
    field(:entity_type, :string)
    field(:entity_id, :binary_id)

    belongs_to(:user, Missionspace.Accounts.User)
    belongs_to(:parent, Missionspace.Chat.Message)
    belongs_to(:quote, Missionspace.Chat.Message)

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:text, :entity_type, :entity_id, :user_id, :parent_id, :quote_id])
    |> validate_required([:text, :entity_type, :entity_id, :user_id])
    |> validate_inclusion(:entity_type, ["task", "doc", "channel", "dm"])
    |> sanitize_content()
  end

  # Sanitize markdown content — strip dangerous HTML tags
  defp sanitize_content(changeset) do
    case get_change(changeset, :text) do
      nil ->
        changeset

      text ->
        sanitized = Missionspace.ContentSanitizer.sanitize_markdown(text)
        put_change(changeset, :text, sanitized)
    end
  end
end
