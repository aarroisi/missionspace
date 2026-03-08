defmodule Missionspace.Automation do
  @moduledoc """
  Workspace automation settings and autonomous task execution records.
  """

  import Ecto.Query, warn: false

  alias Missionspace.Automation.AgentRun
  alias Missionspace.Automation.AgentRunEvent
  alias Missionspace.Automation.CodexOAuth
  alias Missionspace.Automation.GitHubApp
  alias Missionspace.Automation.RunJob
  alias Missionspace.Automation.Secrets
  alias Missionspace.Automation.TaskAgentAssignment
  alias Missionspace.Automation.WorkspaceAutomationRepository
  alias Missionspace.Automation.WorkspaceAutomationSetting
  alias Missionspace.Lists.List
  alias Missionspace.Lists.Task
  alias Missionspace.Repo

  @doc """
  Returns workspace automation settings, creating defaults if needed.
  """
  def get_workspace_setting(workspace_id) when is_binary(workspace_id) do
    with {:ok, _setting} <- ensure_workspace_setting(workspace_id),
         %WorkspaceAutomationSetting{} = setting <-
           WorkspaceAutomationSetting
           |> where([s], s.workspace_id == ^workspace_id)
           |> preload([:repositories])
           |> Repo.one() do
      {:ok, sort_setting_repositories(setting)}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Updates workspace automation settings.
  """
  def update_workspace_setting(workspace_id, attrs)
      when is_binary(workspace_id) and is_map(attrs) do
    attrs = normalize_attr_keys(attrs)
    repositories = fetch_value(attrs, :repositories)

    Repo.transaction(fn ->
      with {:ok, setting} <- ensure_workspace_setting(workspace_id),
           {:ok, setting_attrs} <- normalize_setting_attrs(attrs),
           {:ok, encrypted_attrs} <- apply_codex_api_key(setting_attrs, attrs),
           {:ok, updated_setting} <-
             setting
             |> WorkspaceAutomationSetting.changeset(encrypted_attrs)
             |> Repo.update(),
           {:ok, _repositories} <-
             replace_repositories(updated_setting.workspace_id, repositories),
           {:ok, refreshed_setting} <- get_workspace_setting(updated_setting.workspace_id) do
        refreshed_setting
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, setting} -> {:ok, setting}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns Codex connection status and a user-scoped OAuth connect URL.
  """
  def get_codex_connection(workspace_id, user_id)
      when is_binary(workspace_id) and is_binary(user_id) do
    with {:ok, setting} <- get_workspace_setting(workspace_id) do
      connect_url =
        case codex_oauth_module().build_connect_url(workspace_id, user_id) do
          {:ok, url} -> url
          {:error, _reason} -> nil
        end

      connected = is_binary(setting.codex_api_key_ciphertext)

      {:ok,
       %{
         provider: "codex",
         status: codex_connection_status(connected),
         connected: connected,
         auth_method: codex_auth_method(setting),
         connect_url: connect_url,
         key_last4: setting.codex_api_key_last4,
         key_updated_at: setting.codex_api_key_updated_at,
         oauth_account_id: setting.codex_oauth_account_id,
         oauth_plan_type: setting.codex_oauth_plan_type
       }}
    end
  end

  @doc """
  Exchanges a ChatGPT OAuth callback for a Codex credential and stores it.
  """
  def connect_codex_oauth(workspace_id, user_id, code, state)
      when is_binary(workspace_id) and is_binary(user_id) and is_binary(code) and
             is_binary(state) do
    with {:ok, oauth_result} <-
           codex_oauth_module().exchange_code_for_codex_credential(
             workspace_id,
             user_id,
             code,
             state
           ),
         {:ok, setting} <-
           update_workspace_setting(workspace_id, %{
             "codex_api_key" => oauth_result.credential,
             "codex_auth_method" => "chatgpt_oauth",
             "codex_oauth_account_id" => oauth_result.account_id,
             "codex_oauth_plan_type" => oauth_result.plan_type
           }) do
      {:ok, setting}
    end
  end

  def connect_codex_oauth(_workspace_id, _user_id, _code, _state),
    do: {:error, :invalid_oauth_context}

  @doc """
  Starts device-code authorization for ChatGPT-based Codex connection.
  """
  def start_codex_device_authorization(workspace_id)
      when is_binary(workspace_id) do
    with {:ok, _setting} <- ensure_workspace_setting(workspace_id),
         {:ok, session} <- codex_oauth_module().start_device_authorization() do
      {:ok, session}
    end
  end

  @doc """
  Completes device-code authorization and stores the resulting Codex credential.
  """
  def complete_codex_device_authorization(workspace_id, device_auth_id, user_code)
      when is_binary(workspace_id) and is_binary(device_auth_id) and is_binary(user_code) do
    with {:ok, oauth_result} <-
           codex_oauth_module().exchange_device_code_for_codex_credential(
             device_auth_id,
             user_code
           ) do
      case oauth_result do
        %{credential: _credential} = authorized_result ->
          update_workspace_setting(workspace_id, %{
            "codex_api_key" => authorized_result.credential,
            "codex_auth_method" => "chatgpt_oauth",
            "codex_oauth_account_id" => authorized_result.account_id,
            "codex_oauth_plan_type" => authorized_result.plan_type
          })

        _ ->
          {:error, :invalid_oauth_context}
      end
    else
      {:pending, details} -> {:pending, details}
      other -> other
    end
  end

  def complete_codex_device_authorization(_workspace_id, _device_auth_id, _user_code),
    do: {:error, :invalid_oauth_context}

  @doc """
  Removes any stored Codex credential (API key or OAuth-derived credential).
  """
  def disconnect_codex_connection(workspace_id) when is_binary(workspace_id) do
    update_workspace_setting(workspace_id, %{"clear_codex_api_key" => true})
  end

  @doc """
  Returns GitHub App connection status for workspace automation.
  """
  def get_github_connection(workspace_id) when is_binary(workspace_id) do
    with {:ok, setting} <- get_workspace_setting(workspace_id) do
      connected = is_binary(setting.github_app_installation_id)

      installation_details =
        if connected do
          case GitHubApp.get_installation_details(setting.github_app_installation_id) do
            {:ok, details} -> details
            {:error, _reason} -> github_installation_details_defaults()
          end
        else
          github_installation_details_defaults()
        end

      {:ok,
       Map.merge(installation_details, %{
         provider: "github_app",
         status: github_connection_status(setting.github_app_installation_id),
         connected: connected,
         installation_id: setting.github_app_installation_id,
         repository_count: length(setting.repositories)
       })}
    end
  end

  @doc """
  Links a GitHub App installation to workspace automation settings.
  """
  def link_github_installation(workspace_id, installation_id)
      when is_binary(workspace_id) and is_binary(installation_id) do
    if valid_github_installation_id?(installation_id) do
      update_workspace_setting(workspace_id, %{"github_app_installation_id" => installation_id})
    else
      {:error, :invalid_installation_id}
    end
  end

  @doc """
  Unlinks any GitHub App installation from workspace automation settings.
  """
  def unlink_github_installation(workspace_id) when is_binary(workspace_id) do
    with {:ok, setting} <- get_workspace_setting(workspace_id),
         :ok <- maybe_uninstall_github_installation(setting.github_app_installation_id) do
      update_workspace_setting(workspace_id, %{
        "github_app_installation_id" => nil,
        "repositories" => []
      })
    end
  end

  @doc """
  Syncs workspace repository targets from the connected GitHub App installation.
  """
  def sync_workspace_repositories_from_github(workspace_id) when is_binary(workspace_id) do
    with {:ok, setting} <- get_workspace_setting(workspace_id),
         {:ok, installation_id} <- github_installation_id(setting),
         {:ok, github_repositories} <- GitHubApp.list_installation_repositories(installation_id),
         {:ok, updated_setting} <-
           update_workspace_setting(workspace_id, %{"repositories" => github_repositories}) do
      {:ok, updated_setting}
    end
  end

  @doc """
  Assigns an autonomous agent profile to a task.
  """
  def assign_task_agent(workspace_id, task_id, assigned_by_id, attrs \\ %{})

  def assign_task_agent(workspace_id, task_id, assigned_by_id, attrs)
      when is_binary(workspace_id) and is_binary(task_id) and is_binary(assigned_by_id) and
             is_map(attrs) do
    attrs = normalize_attr_keys(attrs)

    with :ok <- ensure_task_in_workspace(task_id, workspace_id) do
      Repo.transaction(fn ->
        from(a in TaskAgentAssignment,
          where: a.workspace_id == ^workspace_id and a.task_id == ^task_id and a.active == true
        )
        |> Repo.update_all(set: [active: false])

        attrs =
          attrs
          |> Map.put_new("provider", "codex")
          |> Map.put_new("mode", "autonomous")
          |> Map.put("active", true)

        %TaskAgentAssignment{
          workspace_id: workspace_id,
          task_id: task_id,
          assigned_by_id: assigned_by_id
        }
        |> TaskAgentAssignment.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, assignment} -> assignment
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
      |> case do
        {:ok, assignment} -> {:ok, assignment}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Returns the active agent assignment for a task.
  """
  def get_active_task_assignment(workspace_id, task_id)
      when is_binary(workspace_id) and is_binary(task_id) do
    TaskAgentAssignment
    |> where([a], a.workspace_id == ^workspace_id and a.task_id == ^task_id and a.active == true)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      assignment -> {:ok, assignment}
    end
  end

  @doc """
  Creates an autonomous agent run record for a task.
  """
  def create_agent_run(workspace_id, task_id, initiated_by_id, attrs \\ %{})

  def create_agent_run(workspace_id, task_id, initiated_by_id, attrs)
      when is_binary(workspace_id) and is_binary(task_id) and is_binary(initiated_by_id) and
             is_map(attrs) do
    attrs = normalize_attr_keys(attrs)

    with :ok <- ensure_task_in_workspace(task_id, workspace_id) do
      Repo.transaction(fn ->
        assignment_id =
          case fetch_value(attrs, :task_agent_assignment_id) do
            nil ->
              case get_active_task_assignment(workspace_id, task_id) do
                {:ok, assignment} -> assignment.id
                _ -> nil
              end

            id ->
              id
          end

        run_attrs =
          attrs
          |> Map.put_new("provider", "codex")
          |> Map.put_new("status", "queued")
          |> Map.put_new("selected_repositories", [])
          |> Map.put_new("pull_request_urls", [])

        run_result =
          %AgentRun{
            workspace_id: workspace_id,
            task_id: task_id,
            initiated_by_id: initiated_by_id,
            task_agent_assignment_id: assignment_id
          }
          |> AgentRun.changeset(run_attrs)
          |> Repo.insert()

        case run_result do
          {:ok, run} ->
            event_attrs = %{
              event_type: "run_enqueued",
              level: "info",
              message: "Agent run queued",
              payload: %{},
              occurred_at: DateTime.utc_now()
            }

            case append_agent_run_event(run, event_attrs) do
              {:ok, _event} ->
                case enqueue_agent_run(run) do
                  {:ok, _job} -> run
                  {:error, reason} -> Repo.rollback(reason)
                end

              {:error, reason} ->
                Repo.rollback(reason)
            end

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
      |> case do
        {:ok, run} -> {:ok, run}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Lists task agent runs in reverse chronological order.
  """
  def list_task_runs(workspace_id, task_id)
      when is_binary(workspace_id) and is_binary(task_id) do
    AgentRun
    |> where([r], r.workspace_id == ^workspace_id and r.task_id == ^task_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Fetches an agent run by id.
  """
  def get_agent_run(run_id) when is_binary(run_id) do
    AgentRun
    |> where([r], r.id == ^run_id)
    |> preload([:task_agent_assignment])
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      run -> {:ok, run}
    end
  end

  @doc """
  Marks a queued agent run as running.
  """
  def mark_agent_run_running(%AgentRun{} = run) do
    case run.status do
      "queued" ->
        with {:ok, updated_run} <-
               run
               |> AgentRun.changeset(%{
                 "status" => "running",
                 "started_at" => DateTime.utc_now(),
                 "completed_at" => nil,
                 "error_message" => nil
               })
               |> Repo.update(),
             {:ok, _event} <-
               append_agent_run_event(updated_run, %{
                 event_type: "run_claimed",
                 level: "info",
                 message: "Agent run claimed for execution",
                 payload: %{},
                 occurred_at: DateTime.utc_now()
               }) do
          {:ok, updated_run}
        end

      "running" ->
        {:ok, run}

      _ ->
        {:error, :run_not_executable}
    end
  end

  @doc """
  Marks a running agent run as succeeded.
  """
  def mark_agent_run_succeeded(%AgentRun{} = run, attrs \\ %{}) when is_map(attrs) do
    run_attrs =
      attrs
      |> put_value(:status, "succeeded")
      |> put_value(:error_message, nil)
      |> put_value(:completed_at, DateTime.utc_now())

    with {:ok, updated_run} <-
           run
           |> AgentRun.changeset(run_attrs)
           |> Repo.update(),
         {:ok, _event} <-
           append_agent_run_event(updated_run, %{
             event_type: "run_succeeded",
             level: "info",
             message: "Agent run completed successfully",
             payload: %{
               pull_request_urls: updated_run.pull_request_urls,
               summary: updated_run.summary
             },
             occurred_at: DateTime.utc_now()
           }) do
      {:ok, updated_run}
    end
  end

  @doc """
  Marks a running agent run as failed.
  """
  def mark_agent_run_failed(%AgentRun{} = run, error_message, attrs \\ %{})
      when is_binary(error_message) and is_map(attrs) do
    run_attrs =
      attrs
      |> put_value(:status, "failed")
      |> put_value(:error_message, error_message)
      |> put_value(:completed_at, DateTime.utc_now())

    with {:ok, updated_run} <-
           run
           |> AgentRun.changeset(run_attrs)
           |> Repo.update(),
         {:ok, _event} <-
           append_agent_run_event(updated_run, %{
             event_type: "run_failed",
             level: "error",
             message: error_message,
             payload: %{},
             occurred_at: DateTime.utc_now()
           }) do
      {:ok, updated_run}
    end
  end

  @doc """
  Returns the decrypted Codex credential for a workspace setting.
  """
  def get_workspace_codex_api_key(workspace_id) when is_binary(workspace_id) do
    with {:ok, setting} <- get_workspace_setting(workspace_id) do
      case setting.codex_api_key_ciphertext do
        ciphertext when is_binary(ciphertext) -> Secrets.decrypt_codex_api_key(ciphertext)
        _ -> {:error, :codex_api_key_not_configured}
      end
    end
  end

  @doc """
  Appends an event for an existing run.
  """
  def append_agent_run_event(%AgentRun{} = run, attrs) when is_map(attrs) do
    %AgentRunEvent{workspace_id: run.workspace_id, agent_run_id: run.id}
    |> AgentRunEvent.changeset(attrs)
    |> Repo.insert()
  end

  defp ensure_workspace_setting(workspace_id) do
    case Repo.get_by(WorkspaceAutomationSetting, workspace_id: workspace_id) do
      %WorkspaceAutomationSetting{} = setting ->
        {:ok, setting}

      nil ->
        %WorkspaceAutomationSetting{workspace_id: workspace_id}
        |> WorkspaceAutomationSetting.changeset(%{})
        |> Repo.insert()
        |> case do
          {:ok, setting} ->
            {:ok, setting}

          {:error, %Ecto.Changeset{} = changeset} ->
            if workspace_setting_conflict?(changeset) do
              {:ok, Repo.get_by!(WorkspaceAutomationSetting, workspace_id: workspace_id)}
            else
              {:error, changeset}
            end
        end
    end
  end

  defp workspace_setting_conflict?(%Ecto.Changeset{} = changeset) do
    Enum.any?(changeset.errors, fn
      {:workspace_id, {_, [constraint: :unique, constraint_name: _name]}} -> true
      _ -> false
    end)
  end

  defp normalize_setting_attrs(attrs) do
    attrs =
      attrs
      |> drop_key(:repositories)
      |> drop_key(:codex_api_key)
      |> drop_key(:clear_codex_api_key)
      |> drop_key(:sprite_base_url)
      |> drop_key(:sprite_org_slug)
      |> drop_key(:default_base_branch)

    {:ok, attrs}
  end

  defp apply_codex_api_key(base_attrs, attrs) do
    codex_api_key = fetch_value(attrs, :codex_api_key)
    clear_key = fetch_value(attrs, :clear_codex_api_key)
    codex_auth_method = normalize_codex_auth_method(fetch_value(attrs, :codex_auth_method))
    oauth_account_id = normalize_optional_string(fetch_value(attrs, :codex_oauth_account_id))
    oauth_plan_type = normalize_optional_string(fetch_value(attrs, :codex_oauth_plan_type))

    cond do
      clear_key == true ->
        {:ok,
         base_attrs
         |> put_value(:codex_api_key_ciphertext, nil)
         |> put_value(:codex_api_key_last4, nil)
         |> put_value(:codex_api_key_updated_at, nil)
         |> put_value(:codex_auth_method, nil)
         |> put_value(:codex_oauth_account_id, nil)
         |> put_value(:codex_oauth_plan_type, nil)}

      is_binary(codex_api_key) and String.trim(codex_api_key) != "" ->
        trimmed_key = String.trim(codex_api_key)
        auth_method = codex_auth_method || "api_key"

        oauth_account_id = if auth_method == "chatgpt_oauth", do: oauth_account_id, else: nil
        oauth_plan_type = if auth_method == "chatgpt_oauth", do: oauth_plan_type, else: nil

        with {:ok, encrypted_key} <- Secrets.encrypt_codex_api_key(trimmed_key) do
          {:ok,
           base_attrs
           |> put_value(:codex_api_key_ciphertext, encrypted_key)
           |> put_value(:codex_api_key_last4, String.slice(trimmed_key, -4, 4))
           |> put_value(:codex_api_key_updated_at, DateTime.utc_now())
           |> put_value(:codex_auth_method, auth_method)
           |> put_value(:codex_oauth_account_id, oauth_account_id)
           |> put_value(:codex_oauth_plan_type, oauth_plan_type)}
        end

      true ->
        {:ok, base_attrs}
    end
  end

  defp replace_repositories(_workspace_id, nil), do: {:ok, []}

  defp replace_repositories(workspace_id, repositories) when is_list(repositories) do
    from(r in WorkspaceAutomationRepository, where: r.workspace_id == ^workspace_id)
    |> Repo.delete_all()

    Enum.reduce_while(repositories, {:ok, []}, fn repository_attrs, {:ok, acc} ->
      case normalize_repository_attrs(repository_attrs) do
        {:ok, normalized_repository_attrs} ->
          %WorkspaceAutomationRepository{workspace_id: workspace_id}
          |> WorkspaceAutomationRepository.changeset(normalized_repository_attrs)
          |> Repo.insert()
          |> case do
            {:ok, repository} -> {:cont, {:ok, [repository | acc]}}
            {:error, changeset} -> {:halt, {:error, changeset}}
          end

        {:error, :invalid_repositories} ->
          {:halt, {:error, :invalid_repositories}}
      end
    end)
  end

  defp replace_repositories(_workspace_id, _), do: {:error, :invalid_repositories}

  defp ensure_task_in_workspace(task_id, workspace_id) do
    exists? =
      Task
      |> join(:inner, [t], l in List, on: l.id == t.list_id)
      |> where([t, l], t.id == ^task_id and l.workspace_id == ^workspace_id)
      |> Repo.exists?()

    if exists?, do: :ok, else: {:error, :not_found}
  end

  defp sort_setting_repositories(%WorkspaceAutomationSetting{} = setting) do
    repositories =
      setting.repositories
      |> Enum.sort_by(fn repository ->
        {repository.provider, repository.repo_owner, repository.repo_name}
      end)

    %{setting | repositories: repositories}
  end

  defp fetch_value(attrs, key) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, key) -> Map.get(attrs, key)
      Map.has_key?(attrs, Atom.to_string(key)) -> Map.get(attrs, Atom.to_string(key))
      true -> nil
    end
  end

  defp drop_key(attrs, key) do
    attrs
    |> Map.delete(key)
    |> Map.delete(Atom.to_string(key))
  end

  defp normalize_repository_attrs(repository_attrs) when is_map(repository_attrs) do
    {:ok,
     %{
       "provider" => fetch_value(repository_attrs, :provider) || "github",
       "repo_owner" => fetch_value(repository_attrs, :repo_owner),
       "repo_name" => fetch_value(repository_attrs, :repo_name),
       "default_branch" => fetch_value(repository_attrs, :default_branch) || "main",
       "enabled" =>
         case fetch_value(repository_attrs, :enabled) do
           nil -> true
           value -> value
         end
     }}
  end

  defp normalize_repository_attrs(_), do: {:error, :invalid_repositories}

  defp put_value(attrs, key, value) do
    Map.put(attrs, Atom.to_string(key), value)
  end

  defp normalize_attr_keys(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn {key, value}, acc ->
      normalized_key =
        case key do
          atom when is_atom(atom) -> Atom.to_string(atom)
          other -> other
        end

      Map.put(acc, normalized_key, value)
    end)
  end

  defp enqueue_agent_run(%AgentRun{} = run) do
    run
    |> build_run_job_changeset()
    |> then(&Oban.insert(Oban, &1))
  end

  defp build_run_job_changeset(%AgentRun{} = run) do
    %{"run_id" => run.id}
    |> RunJob.new()
  end

  defp valid_github_installation_id?(installation_id) when is_binary(installation_id) do
    String.match?(installation_id, ~r/^\d+$/)
  end

  defp github_connection_status(installation_id) when is_binary(installation_id), do: "connected"
  defp github_connection_status(_installation_id), do: "not_connected"

  defp codex_connection_status(true), do: "connected"
  defp codex_connection_status(false), do: "not_connected"

  defp codex_auth_method(%WorkspaceAutomationSetting{} = setting) do
    case normalize_codex_auth_method(setting.codex_auth_method) do
      nil ->
        if is_binary(setting.codex_api_key_ciphertext), do: "api_key", else: nil

      method ->
        method
    end
  end

  defp normalize_codex_auth_method(value) do
    case value do
      "api_key" -> "api_key"
      "chatgpt_oauth" -> "chatgpt_oauth"
      _ -> nil
    end
  end

  defp normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_optional_string(_value), do: nil

  defp github_installation_id(%WorkspaceAutomationSetting{} = setting) do
    case setting.github_app_installation_id do
      installation_id when is_binary(installation_id) and installation_id != "" ->
        {:ok, installation_id}

      _ ->
        {:error, :github_app_installation_not_configured}
    end
  end

  defp maybe_uninstall_github_installation(installation_id)
       when is_binary(installation_id) and installation_id != "" do
    case GitHubApp.delete_installation(installation_id) do
      :ok ->
        :ok

      {:error, :github_app_not_configured} ->
        # Local/test environments can still unlink when server credentials are absent.
        :ok

      {:error, reason} ->
        {:error, {:github_disconnect_failed, reason}}
    end
  end

  defp maybe_uninstall_github_installation(_installation_id), do: :ok

  defp github_installation_details_defaults do
    %{
      account_login: nil,
      account_type: nil,
      account_avatar_url: nil,
      account_url: nil,
      app_slug: nil,
      repository_selection: nil
    }
  end

  defp codex_oauth_module do
    case Application.get_env(:missionspace, :automation_codex_oauth) do
      module when is_atom(module) and not is_nil(module) -> module
      _ -> CodexOAuth
    end
  end
end
