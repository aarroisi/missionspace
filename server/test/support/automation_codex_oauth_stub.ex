defmodule Missionspace.Automation.CodexOAuthStub do
  @moduledoc false

  def build_connect_url(workspace_id, user_id)
      when is_binary(workspace_id) and is_binary(user_id) do
    {:ok,
     "https://auth.openai.com/oauth/authorize?workspace_id=#{workspace_id}&user_id=#{user_id}"}
  end

  def exchange_code_for_codex_credential(_workspace_id, _user_id, "valid-code", "valid-state") do
    {:ok,
     %{
       credential: "sk-chatgpt-oauth-5678",
       account_id: "chatgpt-account-123",
       plan_type: "plus"
     }}
  end

  def exchange_code_for_codex_credential(
        _workspace_id,
        _user_id,
        "missing-credential",
        "valid-state"
      ) do
    {:error, :codex_oauth_missing_credential}
  end

  def exchange_code_for_codex_credential(_workspace_id, _user_id, _code, "expired-state") do
    {:error, :invalid_state}
  end

  def exchange_code_for_codex_credential(_workspace_id, _user_id, _code, _state) do
    {:error, {:codex_oauth_request_failed, 401}}
  end

  def start_device_authorization do
    {:ok,
     %{
       device_auth_id: "deviceauth_123",
       user_code: "K9UQ-CJU67",
       interval_seconds: 5,
       expires_at: "2026-03-08T03:47:50.045856+00:00",
       verification_url: "https://auth.openai.com/codex/device"
     }}
  end

  def exchange_device_code_for_codex_credential("deviceauth_123", "K9UQ-CJU67") do
    {:pending, %{interval_seconds: 5}}
  end

  def exchange_device_code_for_codex_credential("deviceauth_123", "AUTHORIZED-123") do
    {:ok,
     %{
       credential: "sk-chatgpt-oauth-9999",
       account_id: "chatgpt-account-999",
       plan_type: "pro"
     }}
  end

  def exchange_device_code_for_codex_credential(_device_auth_id, _user_code) do
    {:error, {:codex_oauth_request_failed, 401}}
  end
end
