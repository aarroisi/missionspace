defmodule MissionspaceWeb.WorkspaceController do
  use MissionspaceWeb, :controller

  alias Missionspace.Accounts
  alias Missionspace.Authorization.Policy

  action_fallback(MissionspaceWeb.FallbackController)

  plug(:authorize)

  def update(conn, %{"workspace" => workspace_params}) do
    current_user = conn.assigns.current_user

    {:ok, workspace} = Accounts.get_workspace(current_user.workspace_id)

    case Accounts.update_workspace(workspace, workspace_params) do
      {:ok, updated_workspace} ->
        json(conn, %{
          workspace: %{
            id: updated_workspace.id,
            name: updated_workspace.name,
            slug: updated_workspace.slug,
            logo: updated_workspace.logo
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp authorize(conn, _opts) do
    user = conn.assigns.current_user

    if Policy.can?(user, :manage_workspace_members, nil) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Forbidden"})
      |> halt()
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
