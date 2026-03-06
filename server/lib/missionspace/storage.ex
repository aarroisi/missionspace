defmodule Missionspace.Storage do
  @moduledoc """
  Storage module for interacting with Cloudflare R2 using S3-compatible API.
  Handles presigned URL generation and object operations.
  """

  @presigned_url_expires_in 3600

  @doc """
  Generates a presigned URL for uploading a file to R2.
  Returns `{:ok, url}` or `{:error, reason}`.
  """
  def generate_presigned_upload_url(storage_key, content_type) do
    if mock_storage?() do
      {:ok, "https://test-bucket.example.com/upload/#{storage_key}?content-type=#{content_type}"}
    else
      config = get_config()
      ex_aws_config = build_ex_aws_config(config)

      opts = [
        expires_in: @presigned_url_expires_in,
        virtual_host: false,
        query_params: [{"Content-Type", content_type}]
      ]

      case ExAws.S3.presigned_url(ex_aws_config, :put, config[:bucket], storage_key, opts) do
        {:ok, url} -> {:ok, url}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Generates a presigned URL for downloading/viewing a file from R2.
  Returns `{:ok, url}` or `{:error, reason}`.
  """
  def generate_presigned_download_url(storage_key, opts \\ []) do
    if mock_storage?() do
      {:ok, "https://test-bucket.example.com/#{storage_key}"}
    else
      config = get_config()
      ex_aws_config = build_ex_aws_config(config)
      expires_in = Keyword.get(opts, :expires_in, @presigned_url_expires_in)

      url_opts = [
        expires_in: expires_in,
        virtual_host: false
      ]

      case ExAws.S3.presigned_url(ex_aws_config, :get, config[:bucket], storage_key, url_opts) do
        {:ok, url} -> {:ok, url}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Deletes an object from R2.
  Returns `:ok` or `{:error, reason}`.
  """
  def delete_object(storage_key) do
    if mock_storage?() do
      :ok
    else
      config = get_config()

      case config[:bucket]
           |> ExAws.S3.delete_object(storage_key)
           |> ExAws.request(build_request_config(config)) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Checks if an object exists in R2.
  Returns `{:ok, true}`, `{:ok, false}`, or `{:error, reason}`.
  """
  def object_exists?(storage_key) do
    config = get_config()

    case config[:bucket]
         |> ExAws.S3.head_object(storage_key)
         |> ExAws.request(build_request_config(config)) do
      {:ok, _response} -> {:ok, true}
      {:error, {:http_error, 404, _}} -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a storage key for an asset.
  Format: {workspace_id}/{asset_type}/{year}/{month}/{uuid}.{extension}
  """
  def generate_storage_key(workspace_id, asset_type, filename) do
    now = DateTime.utc_now()
    uuid = UUIDv7.generate()
    extension = get_extension(filename)

    year = now.year |> Integer.to_string()
    month = now.month |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{workspace_id}/#{asset_type}/#{year}/#{month}/#{uuid}#{extension}"
  end

  # Private functions

  defp get_config do
    Application.get_env(:missionspace, :r2, [])
  end

  defp build_request_config(config) do
    [
      access_key_id: config[:access_key_id],
      secret_access_key: config[:secret_access_key],
      host: config[:host],
      region: config[:region] || "auto"
    ]
  end

  defp build_ex_aws_config(config) do
    %{
      access_key_id: config[:access_key_id],
      secret_access_key: config[:secret_access_key],
      scheme: "https://",
      host: config[:host],
      region: config[:region] || "auto"
    }
  end

  defp get_extension(filename) do
    case Path.extname(filename) do
      "" -> ""
      ext -> ext
    end
  end

  defp mock_storage? do
    Application.get_env(:missionspace, :storage_adapter) == :mock
  end
end
