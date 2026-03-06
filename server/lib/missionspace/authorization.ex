defmodule Missionspace.Authorization do
  @moduledoc """
  Authorization helper functions for filtering resources based on user access.
  """

  alias Missionspace.Accounts.User
  alias Missionspace.Projects

  @doc """
  Returns the project IDs that a user has access to.
  Returns :all for owners (they can access everything).
  """
  def accessible_project_ids(%User{role: "owner"}), do: :all

  def accessible_project_ids(%User{id: user_id}) do
    Projects.get_user_project_ids(user_id)
  end
end
