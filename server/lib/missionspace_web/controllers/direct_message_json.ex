defmodule MissionspaceWeb.DirectMessageJSON do
  alias Missionspace.Chat.DirectMessage

  @doc """
  Renders a list of direct_messages.
  """
  def index(%{page: page}) do
    %{
      data: for(dm <- page.entries, do: data(dm)),
      metadata: %{
        after: page.metadata.after,
        before: page.metadata.before,
        limit: page.metadata.limit
      }
    }
  end

  def index(%{direct_messages: direct_messages}) do
    %{data: for(direct_message <- direct_messages, do: data(direct_message))}
  end

  @doc """
  Renders a single direct_message.
  """
  def show(%{direct_message: direct_message}) do
    %{data: data(direct_message)}
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%DirectMessage{} = dm) do
    %{
      id: dm.id,
      starred: dm.starred,
      user1_id: dm.user1_id,
      user2_id: dm.user2_id,
      user1: user_data(dm.user1),
      user2: user_data(dm.user2),
      inserted_at: dm.inserted_at,
      updated_at: dm.updated_at
    }
  end

  defp user_data(%Missionspace.Accounts.User{} = user) do
    %{id: user.id, name: user.name, email: user.email, avatar: user.avatar}
  end

  defp user_data(_), do: nil

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
