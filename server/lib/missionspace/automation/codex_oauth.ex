defmodule Missionspace.Automation.CodexOAuth do
  @moduledoc false

  @default_auth_base_url "https://auth.openai.com"
  @default_client_id "app_EMoamEEZ73f0CkXaXp7hrann"
  @default_scope "openid profile email offline_access api.connectors.read api.connectors.invoke"
  @default_originator "codex_cli_rs"
  @default_callback_path "/settings/automation"
  @default_state_max_age_seconds 15 * 60
  @state_salt "codex-oauth-connect"

  @spec build_connect_url(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def build_connect_url(workspace_id, user_id)
      when is_binary(workspace_id) and is_binary(user_id) do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, redirect_uri} <- build_redirect_uri(config),
         state <- sign_state(workspace_id, user_id),
         code_verifier <- code_verifier_for_state(state),
         code_challenge <- code_challenge_for(code_verifier),
         authorize_url <- authorize_url(config.auth_base_url),
         query <-
           URI.encode_query(%{
             "response_type" => "code",
             "client_id" => config.client_id,
             "redirect_uri" => redirect_uri,
             "scope" => config.scope,
             "code_challenge" => code_challenge,
             "code_challenge_method" => "S256",
             "id_token_add_organizations" => "true",
             "codex_cli_simplified_flow" => "true",
             "originator" => config.originator,
             "state" => state
           }) do
      {:ok, "#{authorize_url}?#{query}"}
    end
  end

  def build_connect_url(_workspace_id, _user_id), do: {:error, :invalid_oauth_context}

  @spec exchange_code_for_codex_credential(String.t(), String.t(), String.t(), String.t()) ::
          {:ok,
           %{credential: String.t(), account_id: String.t() | nil, plan_type: String.t() | nil}}
          | {:error, term()}
  def exchange_code_for_codex_credential(workspace_id, user_id, code, state)
      when is_binary(workspace_id) and is_binary(user_id) and is_binary(code) and is_binary(state) do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, redirect_uri} <- build_redirect_uri(config),
         {:ok, claims} <- verify_state(state, config.state_max_age_seconds),
         :ok <- verify_state_context(claims, workspace_id, user_id),
         code_verifier <- code_verifier_for_state(state),
         {:ok, authorization_tokens} <-
           request_tokens(config.auth_base_url, %{
             "grant_type" => "authorization_code",
             "code" => code,
             "redirect_uri" => redirect_uri,
             "client_id" => config.client_id,
             "code_verifier" => code_verifier
           }),
         {:ok, codex_credential} <-
           exchange_authorization_tokens_for_credential(config, authorization_tokens) do
      {:ok,
       %{
         credential: codex_credential,
         account_id: extract_account_id(authorization_tokens),
         plan_type: extract_plan_type(authorization_tokens)
       }}
    end
  end

  def exchange_code_for_codex_credential(_workspace_id, _user_id, _code, _state) do
    {:error, :invalid_oauth_context}
  end

  @spec start_device_authorization() ::
          {:ok,
           %{
             device_auth_id: String.t(),
             user_code: String.t(),
             interval_seconds: pos_integer(),
             expires_at: String.t() | nil,
             verification_url: String.t()
           }}
          | {:error, term()}
  def start_device_authorization do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, body} <-
           request_json(
             String.trim_trailing(config.auth_base_url, "/") <>
               "/api/accounts/deviceauth/usercode",
             %{"client_id" => config.client_id}
           ),
         {:ok, device_auth_id} <- read_required_field(body, "device_auth_id"),
         {:ok, user_code} <- read_required_field(body, "user_code"),
         interval_seconds <- parse_interval_seconds(find_map_value(body, "interval")) do
      {:ok,
       %{
         device_auth_id: device_auth_id,
         user_code: user_code,
         interval_seconds: interval_seconds,
         expires_at: find_map_value(body, "expires_at"),
         verification_url: String.trim_trailing(config.auth_base_url, "/") <> "/codex/device"
       }}
    end
  end

  @spec exchange_device_code_for_codex_credential(String.t(), String.t()) ::
          {:ok,
           %{credential: String.t(), account_id: String.t() | nil, plan_type: String.t() | nil}}
          | {:pending, %{interval_seconds: pos_integer()}}
          | {:error, term()}
  def exchange_device_code_for_codex_credential(device_auth_id, user_code)
      when is_binary(device_auth_id) and is_binary(user_code) do
    with {:ok, config} <- fetch_runtime_config(),
         {:ok, poll_result} <- poll_device_authorization(config, device_auth_id, user_code) do
      case poll_result do
        {:pending, interval_seconds} ->
          {:pending, %{interval_seconds: interval_seconds}}

        {:authorized, body} ->
          with {:ok, authorization_code} <- read_required_field(body, "authorization_code"),
               {:ok, code_verifier} <- read_required_field(body, "code_verifier"),
               {:ok, authorization_tokens} <-
                 request_tokens(config.auth_base_url, %{
                   "grant_type" => "authorization_code",
                   "code" => authorization_code,
                   "redirect_uri" =>
                     String.trim_trailing(config.auth_base_url, "/") <> "/deviceauth/callback",
                   "client_id" => config.client_id,
                   "code_verifier" => code_verifier
                 }),
               {:ok, codex_credential} <-
                 exchange_authorization_tokens_for_credential(config, authorization_tokens) do
            {:ok,
             %{
               credential: codex_credential,
               account_id: extract_account_id(authorization_tokens),
               plan_type: extract_plan_type(authorization_tokens)
             }}
          end
      end
    end
  end

  def exchange_device_code_for_codex_credential(_device_auth_id, _user_code),
    do: {:error, :invalid_oauth_context}

  defp exchange_authorization_tokens_for_credential(config, authorization_tokens)
       when is_map(authorization_tokens) do
    with :error <- maybe_inline_credential(authorization_tokens),
         attempts <- token_exchange_attempts(authorization_tokens),
         {:ok, credential} <-
           do_exchange_token_attempts(
             config.auth_base_url,
             config.client_id,
             attempts,
             nil,
             authorization_tokens
           ) do
      {:ok, credential}
    else
      {:ok, credential} -> {:ok, credential}
      other -> other
    end
  end

  defp maybe_inline_credential(authorization_tokens) do
    case read_required_field(authorization_tokens, "access_token") do
      {:ok, access_token} when is_binary(access_token) and access_token != "" ->
        if api_key_like?(access_token), do: {:ok, access_token}, else: :error

      _ ->
        :error
    end
  end

  defp token_exchange_attempts(authorization_tokens) do
    [
      {"id_token", "urn:ietf:params:oauth:token-type:id_token"},
      {"access_token", "urn:ietf:params:oauth:token-type:access_token"}
    ]
    |> Enum.reduce([], fn {field, subject_token_type}, acc ->
      case read_required_field(authorization_tokens, field) do
        {:ok, subject_token} -> [{subject_token, subject_token_type} | acc]
        _ -> acc
      end
    end)
    |> Enum.reverse()
    |> Enum.uniq()
  end

  defp do_exchange_token_attempts(_auth_base_url, _client_id, [], nil, authorization_tokens),
    do: fallback_oauth_access_token(authorization_tokens)

  defp do_exchange_token_attempts(
         _auth_base_url,
         _client_id,
         [],
         last_error,
         authorization_tokens
       ) do
    case fallback_oauth_access_token(authorization_tokens) do
      {:ok, credential} -> {:ok, credential}
      _ -> last_error
    end
  end

  defp do_exchange_token_attempts(
         auth_base_url,
         client_id,
         [{subject_token, token_type} | rest],
         _,
         authorization_tokens
       ) do
    case exchange_subject_token_for_credential(
           auth_base_url,
           client_id,
           subject_token,
           token_type
         ) do
      {:ok, credential} ->
        {:ok, credential}

      error ->
        do_exchange_token_attempts(
          auth_base_url,
          client_id,
          rest,
          error,
          authorization_tokens
        )
    end
  end

  defp fallback_oauth_access_token(authorization_tokens) when is_map(authorization_tokens) do
    case read_required_field(authorization_tokens, "access_token") do
      {:ok, access_token} -> {:ok, access_token}
      _ -> {:error, :codex_oauth_missing_credential}
    end
  end

  defp exchange_subject_token_for_credential(
         auth_base_url,
         client_id,
         subject_token,
         subject_token_type
       ) do
    with {:ok, response_body} <-
           request_tokens(auth_base_url, %{
             "grant_type" => "urn:ietf:params:oauth:grant-type:token-exchange",
             "client_id" => client_id,
             "requested_token" => "openai-api-key",
             "subject_token" => subject_token,
             "subject_token_type" => subject_token_type
           }),
         {:ok, credential} <- read_required_field(response_body, "access_token") do
      {:ok, credential}
    else
      {:error, :missing_required_field} -> {:error, :codex_oauth_missing_credential}
      other -> other
    end
  end

  defp request_tokens(auth_base_url, form_params) when is_map(form_params) do
    case Req.post(url: token_url(auth_base_url), form: form_params) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 and is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        error_details =
          body
          |> oauth_error_message()
          |> case do
            nil -> status
            message -> "#{status}: #{message}"
          end

        {:error, {:codex_oauth_request_failed, error_details}}

      {:error, reason} ->
        {:error, {:codex_oauth_request_failed, reason}}
    end
  end

  defp request_json(url, payload) when is_binary(url) and is_map(payload) do
    case Req.post(url: url, json: payload) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 and is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:codex_oauth_request_failed, status, body}}

      {:error, reason} ->
        {:error, {:codex_oauth_request_failed, reason}}
    end
  end

  defp poll_device_authorization(config, device_auth_id, user_code) do
    url = String.trim_trailing(config.auth_base_url, "/") <> "/api/accounts/deviceauth/token"

    case Req.post(
           url: url,
           json: %{"device_auth_id" => device_auth_id, "user_code" => user_code}
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 and is_map(body) ->
        {:ok, {:authorized, body}}

      {:ok, %Req.Response{status: status}} when status in [403, 404] ->
        {:ok, {:pending, 5}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:codex_oauth_request_failed, status, body}}

      {:error, reason} ->
        {:error, {:codex_oauth_request_failed, reason}}
    end
  end

  defp parse_interval_seconds(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> 5
    end
  end

  defp parse_interval_seconds(value) when is_integer(value) and value > 0, do: value
  defp parse_interval_seconds(_value), do: 5

  defp fetch_runtime_config do
    oauth_config = Application.get_env(:missionspace, :codex_oauth, [])

    client_id =
      oauth_config
      |> Keyword.get(:client_id, @default_client_id)
      |> normalize_string()

    auth_base_url =
      oauth_config
      |> Keyword.get(:auth_base_url, @default_auth_base_url)
      |> normalize_string()
      |> default_if_nil(@default_auth_base_url)

    scope =
      oauth_config
      |> Keyword.get(:scope, @default_scope)
      |> normalize_string()
      |> default_if_nil(@default_scope)

    originator =
      oauth_config
      |> Keyword.get(:originator, @default_originator)
      |> normalize_string()
      |> default_if_nil(@default_originator)

    callback_path =
      oauth_config
      |> Keyword.get(:callback_path, @default_callback_path)
      |> normalize_string()
      |> default_if_nil(@default_callback_path)

    state_max_age_seconds =
      oauth_config
      |> Keyword.get(:state_max_age_seconds, @default_state_max_age_seconds)
      |> normalize_state_max_age_seconds()

    frontend_url =
      Application.get_env(:missionspace, :frontend_url)
      |> normalize_string()

    cond do
      is_nil(client_id) ->
        {:error, :codex_oauth_not_configured}

      is_nil(frontend_url) ->
        {:error, :codex_oauth_not_configured}

      true ->
        {:ok,
         %{
           client_id: client_id,
           auth_base_url: auth_base_url,
           scope: scope,
           originator: originator,
           callback_path: callback_path,
           frontend_url: frontend_url,
           state_max_age_seconds: state_max_age_seconds
         }}
    end
  end

  defp build_redirect_uri(config) do
    callback_path = "/" <> String.trim_leading(config.callback_path, "/")
    {:ok, String.trim_trailing(config.frontend_url, "/") <> callback_path}
  end

  defp authorize_url(auth_base_url),
    do: String.trim_trailing(auth_base_url, "/") <> "/oauth/authorize"

  defp token_url(auth_base_url), do: String.trim_trailing(auth_base_url, "/") <> "/oauth/token"

  defp code_verifier_for_state(state) when is_binary(state) do
    state
    |> then(&:crypto.mac(:hmac, :sha256, pkce_secret(), &1))
    |> Base.url_encode64(padding: false)
  end

  defp code_challenge_for(code_verifier) do
    :crypto.hash(:sha256, code_verifier)
    |> Base.url_encode64(padding: false)
  end

  defp sign_state(workspace_id, user_id) do
    Phoenix.Token.sign(MissionspaceWeb.Endpoint, @state_salt, %{
      workspace_id: workspace_id,
      user_id: user_id,
      nonce: generate_state_nonce()
    })
  end

  defp verify_state(state, max_age_seconds) do
    case Phoenix.Token.verify(MissionspaceWeb.Endpoint, @state_salt, state,
           max_age: max_age_seconds
         ) do
      {:ok, claims} when is_map(claims) -> {:ok, claims}
      _ -> {:error, :invalid_state}
    end
  end

  defp verify_state_context(claims, workspace_id, user_id) do
    with {:ok, claims_workspace_id} <- read_required_claim(claims, "workspace_id"),
         {:ok, claims_user_id} <- read_required_claim(claims, "user_id"),
         {:ok, _nonce} <- read_required_claim(claims, "nonce") do
      if claims_workspace_id == workspace_id and claims_user_id == user_id do
        :ok
      else
        {:error, :invalid_state}
      end
    else
      _ -> {:error, :invalid_state}
    end
  end

  defp read_required_claim(claims, key) when is_map(claims) and is_binary(key) do
    value = find_map_value(claims, key)

    if is_binary(value) and String.trim(value) != "" do
      {:ok, value}
    else
      {:error, :invalid_state}
    end
  end

  defp read_required_field(map, key) when is_map(map) and is_binary(key) do
    value = find_map_value(map, key)

    if is_binary(value) and String.trim(value) != "" do
      {:ok, value}
    else
      {:error, :missing_required_field}
    end
  end

  defp extract_account_id(authorization_tokens) do
    authorization_tokens
    |> extract_access_token_auth_claims()
    |> read_auth_claim("chatgpt_account_id")
  end

  defp extract_plan_type(authorization_tokens) do
    authorization_tokens
    |> extract_access_token_auth_claims()
    |> read_auth_claim("chatgpt_plan_type")
  end

  defp extract_access_token_auth_claims(authorization_tokens) do
    with {:ok, access_token} <- read_required_field(authorization_tokens, "access_token"),
         {:ok, jwt_claims} <- decode_jwt_claims(access_token),
         auth_claims when is_map(auth_claims) <-
           Map.get(jwt_claims, "https://api.openai.com/auth") do
      auth_claims
    else
      _ -> %{}
    end
  end

  defp read_auth_claim(auth_claims, key) when is_map(auth_claims) do
    case Map.get(auth_claims, key) do
      value when is_binary(value) and value != "" -> value
      _ -> nil
    end
  end

  defp decode_jwt_claims(token) when is_binary(token) do
    case String.split(token, ".") do
      [_header, payload, _signature] ->
        with {:ok, payload_json} <- decode_base64url(payload),
             {:ok, claims} <- Jason.decode(payload_json),
             true <- is_map(claims) do
          {:ok, claims}
        else
          _ -> {:error, :invalid_jwt}
        end

      _ ->
        {:error, :invalid_jwt}
    end
  end

  defp decode_base64url(payload) when is_binary(payload) do
    padding =
      case rem(byte_size(payload), 4) do
        0 -> ""
        2 -> "=="
        3 -> "="
        _ -> ""
      end

    Base.url_decode64(payload <> padding)
  end

  defp oauth_error_message(%{"error_description" => description}) when is_binary(description),
    do: description

  defp oauth_error_message(%{"error" => %{"message" => message}}) when is_binary(message),
    do: message

  defp oauth_error_message(%{"error" => %{"code" => code}}) when is_binary(code), do: code

  defp oauth_error_message(%{"error" => error}) when is_binary(error), do: error
  defp oauth_error_message(body) when is_binary(body), do: normalize_error_text(body)
  defp oauth_error_message(_body), do: nil

  defp normalize_error_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> String.slice(trimmed, 0, 200)
    end
  end

  defp api_key_like?(value) when is_binary(value), do: String.starts_with?(value, "sk-")

  defp generate_state_nonce do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp pkce_secret do
    endpoint_secret =
      MissionspaceWeb.Endpoint.config(:secret_key_base) || "missionspace-dev-codex-oauth-secret"

    :crypto.hash(:sha256, "codex-oauth-pkce:" <> endpoint_secret)
  end

  defp find_map_value(map, key) when is_map(map) and is_binary(key) do
    Enum.find_value(map, fn
      {candidate_key, value} when is_binary(candidate_key) and candidate_key == key ->
        value

      {candidate_key, value} when is_atom(candidate_key) ->
        if Atom.to_string(candidate_key) == key, do: value, else: nil

      _ ->
        nil
    end)
  end

  defp normalize_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_string(value) when is_atom(value) or is_integer(value),
    do: value |> to_string() |> normalize_string()

  defp normalize_string(_value), do: nil

  defp normalize_state_max_age_seconds(value)
       when is_integer(value) and value > 0,
       do: value

  defp normalize_state_max_age_seconds(_value), do: @default_state_max_age_seconds

  defp default_if_nil(nil, default), do: default
  defp default_if_nil(value, _default), do: value
end
