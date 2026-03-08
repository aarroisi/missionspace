defmodule Missionspace.Automation.RunJob do
  @moduledoc false

  use Oban.Worker,
    queue: :automation,
    max_attempts: 5,
    unique: [fields: [:worker, :args], keys: [:run_id], period: :infinity]

  alias Missionspace.Automation.Runner

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) when is_binary(run_id) do
    case Runner.run(run_id) do
      {:ok, _result} ->
        :ok

      {:error, :not_found} ->
        {:discard, :run_not_found}

      {:error, :run_not_executable} ->
        {:discard, :run_not_executable}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def perform(%Oban.Job{}), do: {:discard, :invalid_run_id}
end
