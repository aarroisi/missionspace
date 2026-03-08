defmodule Missionspace.Automation.Secrets do
  @moduledoc false

  @aad "missionspace:automation:codex-api-key"
  @env_key "AUTOMATION_SECRET_KEY"

  def encrypt_codex_api_key(plaintext) when is_binary(plaintext) do
    with key <- encryption_key(),
         iv <- :crypto.strong_rand_bytes(12),
         {ciphertext, tag} <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, 16, true) do
      {:ok, Base.url_encode64(iv <> tag <> ciphertext, padding: false)}
    end
  end

  def decrypt_codex_api_key(encoded_ciphertext) when is_binary(encoded_ciphertext) do
    with {:ok, encrypted} <- Base.url_decode64(encoded_ciphertext, padding: false),
         true <- byte_size(encrypted) > 28,
         <<iv::binary-12, tag::binary-16, ciphertext::binary>> <- encrypted,
         key <- encryption_key(),
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      {:ok, plaintext}
    else
      _ -> {:error, :invalid_ciphertext}
    end
  end

  defp encryption_key do
    case System.get_env(@env_key) do
      nil -> derive_key_from_endpoint_secret()
      "" -> derive_key_from_endpoint_secret()
      value -> normalize_secret_key(value)
    end
  end

  defp normalize_secret_key(value) do
    case Base.decode64(value) do
      {:ok, decoded} when byte_size(decoded) == 32 -> decoded
      _ -> :crypto.hash(:sha256, value)
    end
  end

  defp derive_key_from_endpoint_secret do
    endpoint_secret =
      MissionspaceWeb.Endpoint.config(:secret_key_base) || "missionspace-dev-automation-secret"

    :crypto.hash(:sha256, "automation:" <> endpoint_secret)
  end
end
