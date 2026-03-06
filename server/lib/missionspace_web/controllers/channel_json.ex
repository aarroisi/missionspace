defmodule MissionspaceWeb.ChannelJSON do
  alias Missionspace.Chat.Channel

  @doc """
  Renders a list of channels.
  """
  def index(%{page: page}) do
    %{
      data: for(channel <- page.entries, do: data(channel)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def index(%{channels: channels}) do
    %{data: for(channel <- channels, do: data(channel))}
  end

  @doc """
  Renders a single channel.
  """
  def show(%{channel: channel}) do
    %{data: data(channel)}
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%Channel{} = channel) do
    %{
      id: channel.id,
      name: channel.name,
      visibility: channel.visibility,
      starred: channel.starred,
      created_by_id: channel.created_by_id,
      created_by: get_created_by(channel),
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end

  defp get_created_by(%Channel{created_by: %{id: id, name: name, email: email, avatar: avatar}}),
    do: %{id: id, name: name, email: email, avatar: avatar}

  defp get_created_by(_), do: nil

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
