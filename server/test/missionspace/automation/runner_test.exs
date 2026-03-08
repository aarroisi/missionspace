defmodule Missionspace.Automation.RunnerTest do
  use Missionspace.DataCase

  alias Missionspace.Automation
  alias Missionspace.Automation.AgentRunEvent
  alias Missionspace.Automation.Runner

  setup do
    original_sprite_client = Application.fetch_env(:missionspace, :automation_sprite_client)
    original_github_app = Application.fetch_env(:missionspace, :automation_github_app)

    Application.put_env(:missionspace, :automation_sprite_client, __MODULE__)
    Application.put_env(:missionspace, :automation_github_app, __MODULE__)

    on_exit(fn ->
      restore_env(:automation_sprite_client, original_sprite_client)
      restore_env(:automation_github_app, original_github_app)
      Process.delete(:runner_test_sprite_runtime_config)
      Process.delete(:runner_test_sprite_results)
    end)

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
        title: "Runner async polling"
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
        "run_goal" => "Implement async Sprite polling"
      })

    %{run: run}
  end

  test "polls Sprite status updates until a terminal success", %{run: run} do
    set_sprite_runtime_config(%{poll_interval_ms: 0, max_polls: 5})

    set_sprite_results([
      %{
        status: "running",
        sprite_session_id: "sprite-session-1",
        summary: "Execution started",
        pull_request_urls: [],
        error_message: nil,
        raw: %{}
      },
      %{
        status: "running",
        sprite_session_id: "sprite-session-1",
        summary: "Running tests",
        pull_request_urls: [],
        error_message: nil,
        raw: %{}
      },
      %{
        status: "succeeded",
        sprite_session_id: "sprite-session-1",
        summary: "Opened PR successfully",
        pull_request_urls: ["https://github.com/acme/missionspace/pull/42"],
        error_message: nil,
        raw: %{}
      }
    ])

    assert {:ok, :succeeded} = Runner.run(run.id)

    assert {:ok, updated_run} = Automation.get_agent_run(run.id)
    assert updated_run.status == "succeeded"
    assert updated_run.sprite_session_id == "sprite-session-1"
    assert updated_run.summary == "Opened PR successfully"
    assert updated_run.pull_request_urls == ["https://github.com/acme/missionspace/pull/42"]

    events =
      AgentRunEvent
      |> where([e], e.agent_run_id == ^run.id)
      |> order_by([e], asc: e.inserted_at)
      |> Repo.all()

    assert Enum.any?(events, &(&1.event_type == "run_execution_polling_started"))
    assert Enum.any?(events, &(&1.event_type == "run_execution_status_updated"))
  end

  test "fails run when Sprite polling does not reach terminal status", %{run: run} do
    set_sprite_runtime_config(%{poll_interval_ms: 0, max_polls: 2})

    set_sprite_results([
      %{
        status: "running",
        sprite_session_id: "sprite-session-timeout",
        summary: "Execution started",
        pull_request_urls: [],
        error_message: nil,
        raw: %{}
      },
      %{
        status: "running",
        sprite_session_id: "sprite-session-timeout",
        summary: "Still running",
        pull_request_urls: [],
        error_message: nil,
        raw: %{}
      },
      %{
        status: "running",
        sprite_session_id: "sprite-session-timeout",
        summary: "Still running",
        pull_request_urls: [],
        error_message: nil,
        raw: %{}
      }
    ])

    assert {:ok, :failed} = Runner.run(run.id)

    assert {:ok, updated_run} = Automation.get_agent_run(run.id)
    assert updated_run.status == "failed"
    assert updated_run.sprite_session_id == "sprite-session-timeout"

    assert updated_run.error_message ==
             "Sprite execution did not reach a terminal state before timeout"
  end

  def fetch_runtime_config do
    runtime_config =
      Process.get(:runner_test_sprite_runtime_config, %{poll_interval_ms: 0, max_polls: 5})

    {:ok,
     %{
       api_base_url: "https://sprite.invalid",
       api_token: "sprite-test-token",
       org_slug: "missionspace",
       execute_path: "/api/v1/agent-runs/execute",
       status_path_template: "/api/v1/agent-runs/:session_id",
       timeout_ms: 300_000,
       poll_interval_ms: Map.get(runtime_config, :poll_interval_ms, 0),
       max_polls: Map.get(runtime_config, :max_polls, 5)
     }}
  end

  def execute_run(_payload) do
    pop_sprite_result()
  end

  def get_run_status(_sprite_session_id) do
    pop_sprite_result()
  end

  def create_installation_token(_installation_id) do
    {:ok, "github-installation-token"}
  end

  defp set_sprite_runtime_config(config) do
    Process.put(:runner_test_sprite_runtime_config, config)
  end

  defp set_sprite_results(results) do
    Process.put(:runner_test_sprite_results, results)
  end

  defp pop_sprite_result do
    case Process.get(:runner_test_sprite_results, []) do
      [next_result | rest_results] ->
        Process.put(:runner_test_sprite_results, rest_results)
        {:ok, next_result}

      [] ->
        {:error, :sprite_test_result_queue_exhausted}
    end
  end

  defp restore_env(env_name, {:ok, value}) do
    Application.put_env(:missionspace, env_name, value)
  end

  defp restore_env(env_name, :error) do
    Application.delete_env(:missionspace, env_name)
  end
end
