defmodule Missionspace.ContentSanitizer do
  @moduledoc """
  Sanitizes markdown content to prevent XSS attacks.

  Markdown is inherently safer than HTML since it doesn't execute scripts,
  but raw HTML can be embedded in markdown. This module strips dangerous
  HTML tags and attributes that could be used for XSS.
  """

  @dangerous_tags ~w(script iframe object embed form input textarea select button)
  @dangerous_attrs ~w(onerror onload onclick onmouseover onfocus onblur onchange onsubmit)

  @doc """
  Sanitize markdown content by removing dangerous HTML elements.
  Strips <script>, <iframe>, event handler attributes, and javascript: URLs.
  """
  @spec sanitize_markdown(String.t()) :: String.t()
  def sanitize_markdown(content) when is_binary(content) do
    content
    |> strip_dangerous_tags()
    |> strip_event_handlers()
    |> strip_javascript_urls()
  end

  def sanitize_markdown(nil), do: ""

  # Remove dangerous HTML tags and their content
  defp strip_dangerous_tags(content) do
    Enum.reduce(@dangerous_tags, content, fn tag, acc ->
      # Remove both self-closing and paired tags
      acc
      |> String.replace(~r/<#{tag}[^>]*>.*?<\/#{tag}>/is, "")
      |> String.replace(~r/<#{tag}[^>]*\/?>/i, "")
    end)
  end

  # Remove event handler attributes from any remaining HTML tags
  defp strip_event_handlers(content) do
    Enum.reduce(@dangerous_attrs, content, fn attr, acc ->
      String.replace(acc, ~r/\s#{attr}\s*=\s*"[^"]*"/i, "")
    end)
  end

  # Remove javascript: protocol URLs
  defp strip_javascript_urls(content) do
    String.replace(content, ~r/javascript\s*:/i, "")
  end
end
