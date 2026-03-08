defmodule Missionspace.Automation.RunJobTest do
  use Missionspace.DataCase
  use Oban.Testing, repo: Missionspace.Repo

  alias Missionspace.Automation
  alias Missionspace.Automation.RunJob
  alias Missionspace.Chat.Message

  setup do
    workspace = insert(:workspace)
    owner = insert(:user, workspace_id: workspace.id, role: "owner")

    list =
      insert(:list,
        workspace_id: workspace.id,
        created_by_id: owner.id,
        prefix: "AUTO"
      )

    status = insert(:list_status, list_id: list.id, name: "TODO")

    task =
      insert(:task,
        list_id: list.id,
        status_id: status.id,
        created_by_id: owner.id,
        title: "Improve automation loop"
      )

    {:ok, _setting} =
      Automation.update_workspace_setting(workspace.id, %{
        "autonomous_execution_enabled" => true,
        "github_app_installation_id" => "123456",
        "codex_api_key" => "sk-test-key-1234",
        "repositories" => [
          %{
            "provider" => "github",
            "repo_owner" => "acme",
            "repo_name" => "missionspace",
            "default_branch" => "main",
            "enabled" => true
          }
        ]
      })

    {:ok, run} =
      Automation.create_agent_run(workspace.id, task.id, owner.id, %{
        "run_goal" => "Implement the agent worker loop"
      })

    %{run: run}
  end

  test "create_agent_run enqueues an Oban automation job", %{run: run} do
    assert_enqueued(worker: RunJob, queue: :automation, args: %{"run_id" => run.id})
  end

  test "Oban automation job executes queued run and records failure when Sprite is not configured",
       %{
         run: run
       } do
    assert_enqueued(worker: RunJob, queue: :automation, args: %{"run_id" => run.id})

    assert %{success: 1} = Oban.drain_queue(queue: :automation)

    assert {:ok, updated_run} = Automation.get_agent_run(run.id)
    assert updated_run.status == "failed"
    assert %DateTime{} = updated_run.started_at
    assert updated_run.error_message == "Sprite API is not configured on the server"

    fallback_comment =
      Message
      |> where([m], m.entity_type == "task" and m.entity_id == ^run.task_id)
      |> where([m], m.user_id == ^run.initiated_by_id)
      |> order_by([m], desc: m.inserted_at)
      |> limit(1)
      |> Repo.one()

    assert %Message{} = fallback_comment
    assert fallback_comment.text =~ "Automated execution failed."
    assert fallback_comment.text =~ "Sprite API is not configured on the server"
    assert fallback_comment.text =~ run.id
  end
end
