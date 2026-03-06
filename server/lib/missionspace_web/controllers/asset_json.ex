defmodule MissionspaceWeb.AssetJSON do
  alias Missionspace.Assets.Asset

  @doc """
  Renders the response for request_upload.
  """
  def request_upload(%{asset: asset, upload_url: upload_url}) do
    %{
      data: %{
        id: asset.id,
        upload_url: upload_url,
        storage_key: asset.storage_key
      }
    }
  end

  @doc """
  Renders a single asset.
  """
  def show(%{asset: asset, url: url}) do
    %{data: data(asset, url)}
  end

  def show(%{asset: asset}) do
    %{data: data(asset, nil)}
  end

  @doc """
  Renders a list of assets.
  """
  def index(%{assets: assets}) do
    %{data: for(asset <- assets, do: data(asset, nil))}
  end

  @doc """
  Renders storage usage.
  """
  def storage(%{usage: usage}) do
    %{
      data: %{
        used_bytes: usage.used_bytes,
        quota_bytes: usage.quota_bytes,
        available_bytes: usage.available_bytes
      }
    }
  end

  @doc """
  Renders errors.
  """
  def error(%{changeset: changeset}) do
    %{errors: translate_errors(changeset)}
  end

  defp data(%Asset{} = asset, url) do
    base = %{
      id: asset.id,
      filename: asset.filename,
      content_type: asset.content_type,
      size_bytes: asset.size_bytes,
      asset_type: asset.asset_type,
      status: asset.status,
      uploaded_by_id: asset.uploaded_by_id,
      inserted_at: asset.inserted_at,
      updated_at: asset.updated_at
    }

    if url do
      Map.put(base, :url, url)
    else
      base
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
