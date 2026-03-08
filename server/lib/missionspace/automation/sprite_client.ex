defmodule Missionspace.Automation.SpriteClient do
  @moduledoc false

  @default_execute_path "/api/v1/agent-runs/execute"
  @default_status_path_template "/api/v1/agent-runs/:session_id"
  @default_timeout_ms 300_000
  @default_poll_interval_ms 2_000
  @default_max_polls 120

  @spec fetch_runtime_config() :: {:ok, map()} | {:error, term()}
  def fetch_runtime_config do
    sprite_config = Application.get_env(:missionspace, :sprite, [])

    api_base_url =
      sprite_config
      |> Keyword.get(:api_base_url)
      |> normalize_optional_string()

    api_token =
      sprite_config
      |> Keyword.get(:api_token)
      |> normalize_optional_string()

    org_slug =
      sprite_config
      |> Keyword.get(:org_slug)
      |> normalize_optional_string()

    execute_path =
      sprite_config
      |> Keyword.get(:execute_path, @default_execute_path)
      |> normalize_optional_string()
      |> default_if_nil(@default_execute_path)

    status_path_template =
      sprite_config
      |> Keyword.get(:status_path_template, @default_status_path_template)
      |> normalize_optional_string()
      |> default_if_nil(@default_status_path_template)

    timeout_ms =
      sprite_config
      |> Keyword.get(:timeout_ms, @default_timeout_ms)
      |> normalize_timeout_ms()

    poll_interval_ms =
      sprite_config
      |> Keyword.get(:poll_interval_ms, @default_poll_interval_ms)
      |> normalize_positive_integer(@default_poll_interval_ms)

    max_polls =
      sprite_config
      |> Keyword.get(:max_polls, @default_max_polls)
      |> normalize_positive_integer(@default_max_polls)

    cond do
      is_nil(api_base_url) ->
        {:error, :sprite_not_configured}

      is_nil(api_token) ->
        {:error, :sprite_not_configured}

      is_nil(org_slug) ->
        {:error, :sprite_not_configured}

      true ->
        {:ok,
         %{
           api_base_url: String.trim_trailing(api_base_url, "/"),
           api_token: api_token,
           org_slug: org_slug,
           execute_path: execute_path,
           status_path_template: status_path_template,
           timeout_ms: timeout_ms,
           poll_interval_ms: poll_interval_ms,
           max_polls: max_polls
         }}
    end
  end

  @spec execute_run(map()) :: {:ok, map()} | {:error, term()}
  def execute_run(payload) when is_map(payload) do
    with {:ok, config} <- fetch_runtime_config() do
      request_payload = Map.put_new(payload, "org_slug", config.org_slug)
      request_url = build_url(config.api_base_url, config.execute_path)

      case Req.post(
             url: request_url,
             headers: [
               {"authorization", "Bearer #{config.api_token}"},
               {"accept", "application/json"}
             ],
             json: request_payload,
             receive_timeout: config.timeout_ms
           ) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          extract_execution_result(body)

        {:ok, %Req.Response{status: status}} ->
          {:error, {:sprite_request_failed, status}}

        {:error, reason} ->
          {:error, {:sprite_request_failed, reason}}
      end
    end
  end

  def execute_run(_payload), do: {:error, :invalid_payload}

  @spec get_run_status(String.t()) :: {:ok, map()} | {:error, term()}
  def get_run_status(sprite_session_id) when is_binary(sprite_session_id) do
    with {:ok, config} <- fetch_runtime_config(),
         status_path <- build_status_path(config.status_path_template, sprite_session_id),
         request_url <- build_url(config.api_base_url, status_path) do
      case Req.get(
             url: request_url,
             headers: [
               {"authorization", "Bearer #{config.api_token}"},
               {"accept", "application/json"}
             ],
             receive_timeout: config.timeout_ms
           ) do
        {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
          extract_execution_result(body)

        {:ok, %Req.Response{status: status}} ->
          {:error, {:sprite_request_failed, status}}

        {:error, reason} ->
          {:error, {:sprite_request_failed, reason}}
      end
    end
  end

  def get_run_status(_sprite_session_id), do: {:error, :invalid_sprite_session_id}

  defp extract_execution_result(body) when is_map(body) do
    status =
      body
      |> read_value(["status", :status])
      |> normalize_status()

    sprite_session_id =
      body
      |> read_value([
        "sprite_session_id",
        :sprite_session_id,
        "session_id",
        :session_id,
        "id",
        :id
      ])
      |> normalize_optional_string()

    summary =
      body
      |> read_value(["summary", :summary])
      |> normalize_optional_string()

    pull_request_urls =
      body
      |> read_value(["pull_request_urls", :pull_request_urls, "pullRequests", :pullRequests])
      |> normalize_pull_request_urls()

    error_message =
      body
      |> read_value(["error_message", :error_message, "error", :error])
      |> normalize_optional_string()

    {:ok,
     %{
       status: status,
       sprite_session_id: sprite_session_id,
       summary: summary,
       pull_request_urls: pull_request_urls,
       error_message: error_message,
       raw: body
     }}
  end

  defp extract_execution_result(_), do: {:error, :invalid_sprite_response}

  defp normalize_pull_request_urls(urls) when is_list(urls) do
    urls
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_pull_request_urls(_), do: []

  defp normalize_status(status) when is_binary(status) do
    status
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_status(_), do: "succeeded"

  defp read_value(body, keys) do
    Enum.find_value(keys, fn key -> Map.get(body, key) end)
  end

  defp build_status_path(status_path_template, sprite_session_id) do
    encoded_session_id = URI.encode(sprite_session_id)

    if String.contains?(status_path_template, ":session_id") do
      String.replace(status_path_template, ":session_id", encoded_session_id)
    else
      status_path_template
      |> String.trim_trailing("/")
      |> Kernel.<>("/")
      |> Kernel.<>(encoded_session_id)
    end
  end

  defp build_url(base_url, path) do
    normalized_path =
      if String.starts_with?(path, "/") do
        path
      else
        "/#{path}"
      end

    base_url <> normalized_path
  end

  defp normalize_optional_string(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp normalize_optional_string(_), do: nil

  defp normalize_timeout_ms(value) when is_integer(value) and value > 0, do: value

  defp normalize_timeout_ms(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> @default_timeout_ms
    end
  end

  defp normalize_timeout_ms(_), do: @default_timeout_ms

  defp normalize_positive_integer(value, _default) when is_integer(value) and value > 0,
    do: value

  defp normalize_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> default
    end
  end

  defp normalize_positive_integer(_value, default), do: default

  defp default_if_nil(nil, default), do: default
  defp default_if_nil(value, _default), do: value
end
