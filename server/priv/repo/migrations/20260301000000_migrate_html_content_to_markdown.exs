defmodule Missionspace.Repo.Migrations.MigrateHtmlContentToMarkdown do
  use Ecto.Migration

  import Ecto.Query

  @batch_size 100

  @doc """
  Migrates HTML content to markdown format in docs, messages, tasks, and subtasks.

  This migration converts stored HTML content to markdown using a simple Elixir-based
  converter. Content that is already markdown (no HTML tags) is left unchanged.
  """
  def up do
    # Migrate docs.content
    migrate_table("docs", "content")

    # Migrate messages.text
    migrate_table("messages", "text")

    # Migrate tasks.notes
    migrate_table("tasks", "notes")

    # Migrate subtasks.notes
    migrate_table("subtasks", "notes")
  end

  def down do
    # HTML to markdown is lossy — we can't reverse this migration perfectly.
    # The content will remain as markdown. If a rollback is needed,
    # restore from a database backup.
    :ok
  end

  defp migrate_table(table, column) do
    col_atom = String.to_atom(column)

    # Process in batches to avoid memory issues
    stream =
      repo().stream(
        from(r in table,
          where: not is_nil(field(r, ^col_atom)),
          where: field(r, ^col_atom) != "",
          select: {r.id, field(r, ^col_atom)}
        ),
        max_rows: @batch_size
      )

    repo().transaction(fn ->
      stream
      |> Stream.each(fn {id, content} ->
        if is_html?(content) do
          markdown = html_to_markdown(content)

          repo().query!(
            "UPDATE #{table} SET #{column} = $1 WHERE id = $2",
            [markdown, id]
          )
        end
      end)
      |> Stream.run()
    end)
  end

  # Simple heuristic to detect HTML content
  defp is_html?(content) when is_binary(content) do
    String.contains?(content, "<") and String.match?(content, ~r/<[a-z][\s\S]*>/i)
  end

  defp is_html?(_), do: false

  # Simple HTML to markdown converter for common tags
  defp html_to_markdown(html) do
    html
    # Convert mentions: <span data-type="mention" data-id="uuid">Name</span> → @[Name](member:uuid)
    |> convert_mentions()
    # Convert image blocks
    |> convert_image_blocks()
    # Convert file attachments
    |> convert_file_attachments()
    # Convert image grids
    |> convert_image_grids()
    # Convert common HTML tags to markdown
    |> String.replace(~r/<strong>(.*?)<\/strong>/s, "**\\1**")
    |> String.replace(~r/<b>(.*?)<\/b>/s, "**\\1**")
    |> String.replace(~r/<em>(.*?)<\/em>/s, "*\\1*")
    |> String.replace(~r/<i>(.*?)<\/i>/s, "*\\1*")
    |> String.replace(~r/<del>(.*?)<\/del>/s, "~~\\1~~")
    |> String.replace(~r/<code>(.*?)<\/code>/s, "`\\1`")
    |> String.replace(~r/<pre><code>(.*?)<\/code><\/pre>/s, "```\n\\1\n```")
    |> String.replace(~r/<blockquote>(.*?)<\/blockquote>/s, "> \\1")
    |> String.replace(~r/<h1[^>]*>(.*?)<\/h1>/s, "# \\1")
    |> String.replace(~r/<h2[^>]*>(.*?)<\/h2>/s, "## \\1")
    |> String.replace(~r/<h3[^>]*>(.*?)<\/h3>/s, "### \\1")
    |> String.replace(~r/<a\s+href="([^"]*)"[^>]*>(.*?)<\/a>/s, "[\\2](\\1)")
    # Convert lists
    |> convert_lists()
    # Remove paragraph tags
    |> String.replace(~r/<p[^>]*>(.*?)<\/p>/s, "\\1\n\n")
    # Convert line breaks
    |> String.replace(~r/<br\s*\/?>/, "\n")
    # Strip remaining HTML tags
    |> String.replace(~r/<[^>]+>/, "")
    # Clean up extra whitespace
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp convert_mentions(html) do
    Regex.replace(
      ~r/<span[^>]*data-type="mention"[^>]*data-id="([^"]*)"[^>]*>([^<]*)<\/span>/,
      html,
      "@[\\2](member:\\1)"
    )
  end

  defp convert_image_blocks(html) do
    Regex.replace(
      ~r/<div[^>]*data-type="image-block"[^>]*data-asset-id="([^"]*)"[^>]*data-filename="([^"]*)"[^>]*(?:data-alt="([^"]*)")?[^>]*(?:data-caption="([^"]*)")?[^>]*>.*?<\/div>/s,
      html,
      fn _, asset_id, filename, alt, caption ->
        attrs = ["assetId=\"#{asset_id}\"", "filename=\"#{filename}\""]
        attrs = if alt != "", do: attrs ++ ["alt=\"#{alt}\""], else: attrs
        attrs = if caption != "", do: attrs ++ ["caption=\"#{caption}\""], else: attrs
        "::image{#{Enum.join(attrs, " ")}}"
      end
    )
  end

  defp convert_file_attachments(html) do
    Regex.replace(
      ~r/<div[^>]*data-type="file-attachment"[^>]*data-asset-id="([^"]*)"[^>]*data-filename="([^"]*)"[^>]*data-content-type="([^"]*)"[^>]*data-size="([^"]*)"[^>]*>.*?<\/div>/s,
      html,
      fn _, asset_id, filename, content_type, size ->
        "::file{assetId=\"#{asset_id}\" filename=\"#{filename}\" contentType=\"#{content_type}\" size=\"#{size}\"}"
      end
    )
  end

  defp convert_image_grids(html) do
    Regex.replace(
      ~r/<div[^>]*data-type="image-grid"[^>]*>(.*?)<\/div>/s,
      html,
      fn _, inner ->
        images =
          Regex.scan(
            ~r/<div[^>]*data-type="image-block"[^>]*data-asset-id="([^"]*)"[^>]*data-filename="([^"]*)"[^>]*>/,
            inner
          )
          |> Enum.map(fn [_, asset_id, filename] ->
            "::image{assetId=\"#{asset_id}\" filename=\"#{filename}\"}"
          end)

        if length(images) > 0 do
          ":::image-grid\n#{Enum.join(images, "\n")}\n:::"
        else
          ""
        end
      end
    )
  end

  defp convert_lists(html) do
    # Convert unordered lists
    html =
      Regex.replace(~r/<ul[^>]*>(.*?)<\/ul>/s, html, fn _, inner ->
        items =
          Regex.scan(~r/<li[^>]*>(.*?)<\/li>/s, inner)
          |> Enum.map(fn [_, content] -> "- #{String.trim(content)}" end)

        Enum.join(items, "\n") <> "\n"
      end)

    # Convert ordered lists
    Regex.replace(~r/<ol[^>]*>(.*?)<\/ol>/s, html, fn _, inner ->
      items =
        Regex.scan(~r/<li[^>]*>(.*?)<\/li>/s, inner)
        |> Enum.with_index(1)
        |> Enum.map(fn {[_, content], idx} -> "#{idx}. #{String.trim(content)}" end)

      Enum.join(items, "\n") <> "\n"
    end)
  end
end
