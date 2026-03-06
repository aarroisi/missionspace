defmodule Missionspace.Docs.Doc do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}
  @foreign_key_type Ecto.UUID
  @timestamps_opts [type: :utc_datetime_usec]

  schema "docs" do
    field(:title, :string)
    field(:content, :string, default: "")
    field(:starred, :boolean, virtual: true, default: false)
    field(:sequence_number, :integer)

    belongs_to(:workspace, Missionspace.Accounts.Workspace)
    belongs_to(:author, Missionspace.Accounts.User)
    belongs_to(:doc_folder, Missionspace.Docs.DocFolder)

    timestamps()
  end

  @doc false
  def changeset(doc, attrs) do
    doc
    |> cast(attrs, [:title, :content, :workspace_id, :author_id, :doc_folder_id, :sequence_number])
    |> validate_required([:title, :workspace_id, :author_id, :doc_folder_id])
    |> sanitize_content()
  end

  # Sanitize markdown content — strip dangerous HTML tags that could be
  # embedded in markdown (script, iframe, event handlers, javascript: URLs)
  defp sanitize_content(changeset) do
    case get_change(changeset, :content) do
      nil ->
        changeset

      content ->
        sanitized = Missionspace.ContentSanitizer.sanitize_markdown(content)
        put_change(changeset, :content, sanitized)
    end
  end
end
