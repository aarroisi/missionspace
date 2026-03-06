defmodule MissionspaceWeb.AssetController do
  use MissionspaceWeb, :controller

  alias Missionspace.Assets
  alias Missionspace.Storage
  import Plug.Conn

  action_fallback(MissionspaceWeb.FallbackController)

  plug(:load_resource when action in [:show, :confirm, :delete])

  defp load_resource(conn, _opts) do
    workspace_id = conn.assigns.workspace_id

    case Assets.get_asset(conn.params["id"], workspace_id) do
      {:ok, asset} ->
        assign(conn, :asset, asset)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> Phoenix.Controller.json(%{errors: %{detail: "Not Found"}})
        |> halt()
    end
  end

  @doc """
  Request a presigned URL for uploading a file.
  Creates a pending asset record and returns the upload URL.
  Requires attachable_type and attachable_id to track what the asset is attached to.
  """
  def request_upload(conn, params) do
    current_user = conn.assigns.current_user
    workspace_id = conn.assigns.workspace_id

    filename = params["filename"]
    content_type = params["content_type"]
    size_bytes = params["size_bytes"]
    asset_type = params["asset_type"]
    attachable_type = params["attachable_type"]
    attachable_id = params["attachable_id"]

    storage_key = Storage.generate_storage_key(workspace_id, asset_type, filename)

    asset_attrs = %{
      filename: filename,
      content_type: content_type,
      size_bytes: size_bytes,
      storage_key: storage_key,
      asset_type: asset_type,
      workspace_id: workspace_id,
      uploaded_by_id: current_user.id,
      attachable_type: attachable_type,
      attachable_id: attachable_id
    }

    with {:ok, asset} <- Assets.create_pending_asset(asset_attrs),
         {:ok, upload_url} <- Storage.generate_presigned_upload_url(storage_key, content_type) do
      conn
      |> put_status(:created)
      |> render(:request_upload, asset: asset, upload_url: upload_url)
    else
      {:error, :file_too_large} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "File too large"})

      {:error, :storage_quota_exceeded} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Storage quota exceeded"})

      {:error, :attachable_type_required} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "attachable_type is required"})

      {:error, :attachable_id_required} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "attachable_id is required"})

      {:error, :invalid_attachable_type} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error:
            "Invalid attachable_type. Must be one of: doc, message, user, task, channel, dm, workspace"
        })

      {:error, :attachable_not_found} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Attachable item not found in this workspace"})

      {:error, :invalid_entity_type} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Message has invalid entity type"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  @doc """
  Confirm that an upload has completed.
  Marks the asset as active and updates storage usage.
  Returns the asset with a presigned download URL.
  """
  def confirm(conn, _params) do
    workspace_id = conn.assigns.workspace_id
    asset = conn.assigns.asset

    case Assets.confirm_upload(asset.id, workspace_id) do
      {:ok, confirmed_asset} ->
        # Generate presigned download URL for immediate use
        url =
          case Storage.generate_presigned_download_url(confirmed_asset.storage_key) do
            {:ok, url} -> url
            {:error, _} -> nil
          end

        render(conn, :show, asset: confirmed_asset, url: url)

      {:error, :invalid_status} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Asset is not pending"})

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to confirm upload"})
    end
  end

  @doc """
  Get an asset with its download URL.
  """
  def show(conn, _params) do
    asset = conn.assigns.asset

    case Storage.generate_presigned_download_url(asset.storage_key) do
      {:ok, url} ->
        render(conn, :show, asset: asset, url: url)

      {:error, _reason} ->
        render(conn, :show, asset: asset, url: nil)
    end
  end

  @doc """
  Delete an asset.
  """
  def delete(conn, _params) do
    asset = conn.assigns.asset

    case Assets.delete_asset(asset) do
      {:ok, _deleted} ->
        send_resp(conn, :no_content, "")

      {:error, _reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to delete asset"})
    end
  end

  @doc """
  Get storage usage for the workspace.
  """
  def storage(conn, _params) do
    workspace_id = conn.assigns.workspace_id

    case Assets.get_storage_usage(workspace_id) do
      {:ok, usage} ->
        render(conn, :storage, usage: usage)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Workspace not found"})
    end
  end
end
