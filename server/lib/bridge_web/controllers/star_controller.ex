defmodule BridgeWeb.StarController do
  use BridgeWeb, :controller

  alias Bridge.Stars

  action_fallback(BridgeWeb.FallbackController)

  def toggle(conn, %{"type" => type, "id" => id}) do
    user_id = conn.assigns.current_user.id

    case Stars.toggle_star(user_id, type, id) do
      {:ok, status} ->
        json(conn, %{status: status})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
