defmodule Missionspace.Automation.Runner do
  @moduledoc false

  alias Missionspace.Automation
  alias Missionspace.Automation.GitHubApp
  alias Missionspace.Automation.SpriteClient
  alias Missionspace.Chat

  @success_statuses ["succeeded", "success", "completed"]
  @failed_statuses ["failed", "cancelled"]
  @in_progress_statuses ["queued", "pending", "running", "in_progress", "processing"]
  @default_sprite_poll_interval_ms 2_000
  @default_sprite_max_polls 120

  @spec run(String.t()) :: {:ok, :succeeded | :failed} | {:error, term()}
  def run(run_id) when is_binary(run_id) do
    with {:ok, run} <- Automation.get_agent_run(run_id),
         {:ok, run} <- Automation.mark_agent_run_running(run) do
      _ =
        Automation.append_agent_run_event(run, %{
          event_type: "run_execution_started",
          level: "info",
          message: "Executing run in isolated environment",
          payload: %{},
          occurred_at: DateTime.utc_now()
        })

      case execute(run) do
        {:ok, success_attrs} ->
          case Automation.mark_agent_run_succeeded(run, success_attrs) do
            {:ok, updated_run} ->
              _ = maybe_post_success_fallback_comment(updated_run, success_attrs)
              {:ok, :succeeded}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {error_message, failure_attrs} = failure_details(reason)

          case Automation.mark_agent_run_failed(run, error_message, failure_attrs) do
            {:ok, updated_run} ->
              _ =
                post_task_fallback_comment(
                  updated_run,
                  failure_comment_message(updated_run, error_message)
                )

              {:ok, :failed}

            {:error, mark_failed_reason} ->
              {:error, mark_failed_reason}
          end
      end
    end
  end

  def run(_run_id), do: {:error, :invalid_run_id}

  defp execute(run) do
    sprite_client = sprite_client_module()
    github_app = github_app_module()

    with {:ok, setting} <- Automation.get_workspace_setting(run.workspace_id),
         :ok <- ensure_autonomous_execution_enabled(setting),
         {:ok, sprite_runtime} <- sprite_client.fetch_runtime_config(),
         {:ok, codex_api_key} <- Automation.get_workspace_codex_api_key(run.workspace_id),
         {:ok, github_installation_id} <- github_installation_id(setting),
         {:ok, github_token} <- github_app.create_installation_token(github_installation_id),
         repositories <- selected_repositories(run, setting.repositories),
         :ok <- ensure_repositories_present(repositories),
         payload <- build_sprite_payload(run, setting, repositories, codex_api_key, github_token),
         {:ok, sprite_result} <- sprite_client.execute_run(payload) do
      resolve_sprite_result(run, sprite_client, sprite_runtime, sprite_result, setting)
    end
  end

  defp resolve_sprite_result(run, sprite_client, sprite_runtime, sprite_result, setting) do
    case sprite_result.status do
      status when status in @success_statuses ->
        {:ok, success_attrs(sprite_result, setting)}

      status when status in @failed_statuses ->
        {:error,
         {:sprite_execution_failed, sprite_result.error_message || "Sprite execution failed",
          sprite_result.sprite_session_id}}

      status when status in @in_progress_statuses ->
        poll_sprite_until_terminal(run, sprite_client, sprite_runtime, sprite_result, setting)

      status ->
        {:error,
         {:sprite_execution_failed, "Sprite returned unsupported status '#{status}'",
          sprite_result.sprite_session_id}}
    end
  end

  defp poll_sprite_until_terminal(run, sprite_client, sprite_runtime, sprite_result, setting) do
    with {:ok, sprite_session_id} <- ensure_sprite_session_id(sprite_result) do
      _ =
        Automation.append_agent_run_event(run, %{
          event_type: "run_execution_polling_started",
          level: "info",
          message: "Sprite execution accepted; waiting for terminal status",
          payload: %{status: sprite_result.status, sprite_session_id: sprite_session_id},
          occurred_at: DateTime.utc_now()
        })

      do_poll_sprite_until_terminal(
        run,
        sprite_client,
        sprite_runtime,
        sprite_session_id,
        sprite_result.status,
        setting,
        sprite_max_polls(sprite_runtime)
      )
    end
  end

  defp do_poll_sprite_until_terminal(
         _run,
         _sprite_client,
         _sprite_runtime,
         sprite_session_id,
         _last_status,
         _setting,
         0
       ) do
    {:error, {:sprite_execution_timeout, sprite_session_id}}
  end

  defp do_poll_sprite_until_terminal(
         run,
         sprite_client,
         sprite_runtime,
         sprite_session_id,
         last_status,
         setting,
         attempts_remaining
       ) do
    sleep_if_needed(sprite_poll_interval_ms(sprite_runtime))

    with {:ok, sprite_result} <- sprite_client.get_run_status(sprite_session_id) do
      status = sprite_result.status

      maybe_append_poll_status_event(run, sprite_result, last_status)

      case status do
        terminal_status when terminal_status in @success_statuses ->
          {:ok, success_attrs(sprite_result, setting)}

        terminal_status when terminal_status in @failed_statuses ->
          {:error,
           {:sprite_execution_failed, sprite_result.error_message || "Sprite execution failed",
            sprite_session_id}}

        polling_status when polling_status in @in_progress_statuses ->
          do_poll_sprite_until_terminal(
            run,
            sprite_client,
            sprite_runtime,
            sprite_session_id,
            polling_status,
            setting,
            attempts_remaining - 1
          )

        unsupported_status ->
          {:error,
           {:sprite_execution_failed,
            "Sprite returned unsupported status '#{unsupported_status}'", sprite_session_id}}
      end
    end
  end

  defp maybe_append_poll_status_event(run, sprite_result, last_status) do
    if sprite_result.status != last_status do
      _ =
        Automation.append_agent_run_event(run, %{
          event_type: "run_execution_status_updated",
          level: "info",
          message: "Sprite status updated to '#{sprite_result.status}'",
          payload: %{
            status: sprite_result.status,
            sprite_session_id: sprite_result.sprite_session_id,
            summary: sprite_result.summary
          },
          occurred_at: DateTime.utc_now()
        })
    end

    :ok
  end

  defp ensure_sprite_session_id(sprite_result) do
    case sprite_result.sprite_session_id do
      sprite_session_id when is_binary(sprite_session_id) and sprite_session_id != "" ->
        {:ok, sprite_session_id}

      _ ->
        {:error, :sprite_polling_requires_session_id}
    end
  end

  defp success_attrs(sprite_result, setting) do
    %{
      "sprite_session_id" => sprite_result.sprite_session_id,
      "summary" => normalize_summary(sprite_result.summary),
      "pull_request_urls" => sprite_result.pull_request_urls,
      "auto_open_prs" => setting.auto_open_prs
    }
  end

  defp ensure_autonomous_execution_enabled(setting) do
    if setting.autonomous_execution_enabled do
      :ok
    else
      {:error, :autonomous_execution_disabled}
    end
  end

  defp github_installation_id(setting) do
    case setting.github_app_installation_id do
      installation_id when is_binary(installation_id) and installation_id != "" ->
        {:ok, installation_id}

      _ ->
        {:error, :github_app_installation_not_configured}
    end
  end

  defp selected_repositories(run, repositories) do
    enabled_repositories = Enum.filter(repositories, & &1.enabled)

    selected_identifiers =
      run.selected_repositories
      |> Enum.filter(&is_binary/1)
      |> MapSet.new()

    candidate_repositories =
      if MapSet.size(selected_identifiers) == 0 do
        enabled_repositories
      else
        Enum.filter(enabled_repositories, fn repository ->
          MapSet.member?(selected_identifiers, repository_identifier(repository))
        end)
      end

    Enum.map(candidate_repositories, fn repository ->
      %{
        "provider" => repository.provider,
        "repo_owner" => repository.repo_owner,
        "repo_name" => repository.repo_name,
        "default_branch" => repository.default_branch
      }
    end)
  end

  defp repository_identifier(repository) do
    "#{repository.repo_owner}/#{repository.repo_name}"
  end

  defp ensure_repositories_present([]), do: {:error, :no_repositories_configured}
  defp ensure_repositories_present(_repositories), do: :ok

  defp build_sprite_payload(run, setting, repositories, codex_api_key, github_token) do
    %{
      "run_id" => run.id,
      "workspace_id" => run.workspace_id,
      "task_id" => run.task_id,
      "provider" => run.provider,
      "run_goal" => resolve_run_goal(run),
      "auto_open_prs" => setting.auto_open_prs,
      "repositories" => repositories,
      "environment" => %{
        "CODEX_API_KEY" => codex_api_key,
        "GITHUB_TOKEN" => github_token
      }
    }
  end

  defp failure_details({:sprite_execution_failed, message, sprite_session_id})
       when is_binary(message) do
    {message, %{"sprite_session_id" => sprite_session_id}}
  end

  defp failure_details(:autonomous_execution_disabled) do
    {"Autonomous execution is disabled for this workspace", %{}}
  end

  defp failure_details(:sprite_not_configured) do
    {"Sprite API is not configured on the server", %{}}
  end

  defp failure_details(:sprite_polling_requires_session_id) do
    {"Sprite execution did not return a session id for status polling", %{}}
  end

  defp failure_details({:sprite_execution_timeout, sprite_session_id}) do
    {"Sprite execution did not reach a terminal state before timeout",
     %{"sprite_session_id" => sprite_session_id}}
  end

  defp failure_details(:codex_api_key_not_configured) do
    {"Codex API key is not configured for this workspace", %{}}
  end

  defp failure_details(:github_app_installation_not_configured) do
    {"GitHub App installation is not linked for this workspace", %{}}
  end

  defp failure_details(:github_app_not_configured) do
    {"GitHub App credentials are not configured on the server", %{}}
  end

  defp failure_details(:no_repositories_configured) do
    {"No enabled repositories are configured for this run", %{}}
  end

  defp failure_details({:github_request_failed, status}) do
    {"Failed to mint GitHub installation token (#{inspect(status)})", %{}}
  end

  defp failure_details({:sprite_request_failed, status}) do
    {"Sprite API request failed (#{inspect(status)})", %{}}
  end

  defp failure_details({:error, reason}) do
    failure_details(reason)
  end

  defp failure_details(reason) do
    {"Run execution failed: #{inspect(reason)}", %{}}
  end

  defp sprite_client_module do
    case Application.get_env(:missionspace, :automation_sprite_client) do
      module when is_atom(module) and not is_nil(module) -> module
      _ -> SpriteClient
    end
  end

  defp github_app_module do
    case Application.get_env(:missionspace, :automation_github_app) do
      module when is_atom(module) and not is_nil(module) -> module
      _ -> GitHubApp
    end
  end

  defp sprite_poll_interval_ms(sprite_runtime) do
    case Map.get(sprite_runtime, :poll_interval_ms, @default_sprite_poll_interval_ms) do
      poll_interval_ms when is_integer(poll_interval_ms) and poll_interval_ms >= 0 ->
        poll_interval_ms

      _ ->
        @default_sprite_poll_interval_ms
    end
  end

  defp sprite_max_polls(sprite_runtime) do
    case Map.get(sprite_runtime, :max_polls, @default_sprite_max_polls) do
      max_polls when is_integer(max_polls) and max_polls > 0 ->
        max_polls

      _ ->
        @default_sprite_max_polls
    end
  end

  defp sleep_if_needed(poll_interval_ms)
       when is_integer(poll_interval_ms) and poll_interval_ms > 0 do
    Process.sleep(poll_interval_ms)
  end

  defp sleep_if_needed(_poll_interval_ms), do: :ok

  defp resolve_run_goal(run) do
    cond do
      is_binary(run.run_goal) and String.trim(run.run_goal) != "" ->
        String.trim(run.run_goal)

      run.task_agent_assignment && is_binary(run.task_agent_assignment.instructions) &&
          String.trim(run.task_agent_assignment.instructions) != "" ->
        String.trim(run.task_agent_assignment.instructions)

      true ->
        "Complete task #{run.task_id}"
    end
  end

  defp maybe_post_success_fallback_comment(run, success_attrs) when is_map(success_attrs) do
    if should_post_success_fallback_comment?(success_attrs) do
      post_task_fallback_comment(run, success_without_pr_comment_message(run, success_attrs))
    else
      :ok
    end
  end

  defp maybe_post_success_fallback_comment(_run, _success_attrs), do: :ok

  defp should_post_success_fallback_comment?(success_attrs) do
    auto_open_prs = Map.get(success_attrs, "auto_open_prs")
    pull_request_urls = Map.get(success_attrs, "pull_request_urls", [])

    auto_open_prs == true and pull_request_urls == []
  end

  defp success_without_pr_comment_message(run, success_attrs) do
    summary =
      success_attrs
      |> Map.get("summary")
      |> normalize_summary()

    [
      "Automated execution completed, but no pull request URL was returned.",
      "",
      "Summary: #{summary}",
      "Run ID: #{run.id}",
      "",
      "Please review the run details and continue manually if needed."
    ]
    |> Enum.join("\n")
  end

  defp failure_comment_message(run, error_message) do
    [
      "Automated execution failed.",
      "",
      "Reason: #{error_message}",
      "Run ID: #{run.id}",
      "",
      "Please review workspace automation settings and retry."
    ]
    |> Enum.join("\n")
  end

  defp post_task_fallback_comment(run, message) when is_binary(message) do
    case Chat.create_message_for_entity("task", run.task_id, run.initiated_by_id, message) do
      {:ok, _message} ->
        _ =
          Automation.append_agent_run_event(run, %{
            event_type: "run_task_fallback_comment_posted",
            level: "info",
            message: "Posted fallback update comment to task",
            payload: %{},
            occurred_at: DateTime.utc_now()
          })

        :ok

      {:error, reason} ->
        _ =
          Automation.append_agent_run_event(run, %{
            event_type: "run_task_fallback_comment_failed",
            level: "warning",
            message: "Failed to post fallback task comment: #{inspect(reason)}",
            payload: %{},
            occurred_at: DateTime.utc_now()
          })

        {:error, reason}
    end
  end

  defp post_task_fallback_comment(_run, _message), do: :ok

  defp normalize_summary(summary) when is_binary(summary) do
    summary = String.trim(summary)
    if summary == "", do: "Execution completed in isolated environment.", else: summary
  end

  defp normalize_summary(_summary), do: "Execution completed in isolated environment."
end
