defmodule Missionspace.Repo.Migrations.SetDoneStatusIsDone do
  use Ecto.Migration

  def up do
    # Set is_done=true for existing statuses named "DONE" (case insensitive)
    execute("UPDATE list_statuses SET is_done = true WHERE UPPER(name) = 'DONE'")
  end

  def down do
    # Reset is_done to false
    execute("UPDATE list_statuses SET is_done = false WHERE UPPER(name) = 'DONE'")
  end
end
