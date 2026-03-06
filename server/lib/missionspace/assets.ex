defmodule Missionspace.Assets do
  @moduledoc """
  The Assets context for managing file uploads and storage.
  """

  import Ecto.Query, warn: false
  alias Missionspace.Repo
  alias Missionspace.Assets.Asset
  alias Missionspace.Accounts.Workspace

  # File size limits in bytes
  @max_avatar_size 5 * 1024 * 1024
  @max_file_size 25 * 1024 * 1024

  def max_avatar_size, do: @max_avatar_size
  def max_file_size, do: @max_file_size

  @doc """
  Gets an asset by ID within a workspace.
  Returns `{:ok, asset}` if found, `{:error, :not_found}` otherwise.
  """
  def get_asset(id, workspace_id) do
    case Asset
         |> where([a], a.workspace_id == ^workspace_id)
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      asset -> {:ok, asset}
    end
  end

  @doc """
  Gets an active asset by ID within a workspace.
  """
  def get_active_asset(id, workspace_id) do
    case Asset
         |> where([a], a.workspace_id == ^workspace_id and a.status == "active")
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      asset -> {:ok, asset}
    end
  end

  @doc """
  Creates a pending asset record and checks storage quota.
  Validates that attachable_type and attachable_id are present and belong to the workspace.
  Returns `{:ok, asset}` or `{:error, reason}`.
  """
  def create_pending_asset(attrs) do
    workspace_id = attrs[:workspace_id] || attrs["workspace_id"]
    size_bytes = attrs[:size_bytes] || attrs["size_bytes"]
    asset_type = attrs[:asset_type] || attrs["asset_type"]
    attachable_type = attrs[:attachable_type] || attrs["attachable_type"]
    attachable_id = attrs[:attachable_id] || attrs["attachable_id"]

    with :ok <- validate_file_size(size_bytes, asset_type),
         :ok <- check_storage_quota(workspace_id, size_bytes),
         :ok <- validate_attachable_ownership(workspace_id, attachable_type, attachable_id) do
      %Asset{}
      |> Asset.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Confirms an upload by marking the asset as active and updating storage usage.
  """
  def confirm_upload(asset_id, workspace_id) do
    Repo.transaction(fn ->
      with {:ok, asset} <- get_asset(asset_id, workspace_id),
           :ok <- validate_pending_status(asset),
           {:ok, updated_asset} <- update_asset_status(asset, "active"),
           {:ok, _workspace} <- increment_storage_usage(workspace_id, asset.size_bytes) do
        updated_asset
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Deletes an asset immediately and reclaims storage.
  """
  def delete_asset(%Asset{} = asset) do
    Repo.transaction(fn ->
      # Delete from R2 first
      case Missionspace.Storage.delete_object(asset.storage_key) do
        :ok -> :ok
        {:error, _reason} -> :ok
      end

      # Reclaim storage if asset was active
      if asset.status == "active" do
        decrement_storage_usage(asset.workspace_id, asset.size_bytes)
      end

      # Delete the DB record
      case Repo.delete(asset) do
        {:ok, deleted_asset} -> deleted_asset
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Deletes an asset by ID within a workspace.
  """
  def delete_asset(asset_id, workspace_id) do
    case get_asset(asset_id, workspace_id) do
      {:ok, asset} -> delete_asset(asset)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets storage usage for a workspace.
  """
  def get_storage_usage(workspace_id) do
    case Repo.get(Workspace, workspace_id) do
      nil ->
        {:error, :not_found}

      workspace ->
        {:ok,
         %{
           used_bytes: workspace.storage_used_bytes,
           quota_bytes: workspace.storage_quota_bytes,
           available_bytes: workspace.storage_quota_bytes - workspace.storage_used_bytes
         }}
    end
  end

  @doc """
  Lists assets for a workspace with optional filtering.
  """
  def list_assets(workspace_id, opts \\ []) do
    asset_type = Keyword.get(opts, :asset_type)
    status = Keyword.get(opts, :status, "active")

    query =
      Asset
      |> where([a], a.workspace_id == ^workspace_id)
      |> where([a], a.status == ^status)
      |> order_by([a], desc: a.inserted_at)

    query =
      if asset_type do
        where(query, [a], a.asset_type == ^asset_type)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Attaches an asset to an item (doc, message, user, etc.).
  """
  def attach_asset(asset_id, workspace_id, attachable_type, attachable_id) do
    with {:ok, asset} <- get_asset(asset_id, workspace_id) do
      asset
      |> Asset.changeset(%{attachable_type: attachable_type, attachable_id: attachable_id})
      |> Repo.update()
    end
  end

  @doc """
  Lists all assets attached to a specific item.
  """
  def list_assets_for_item(workspace_id, attachable_type, attachable_id) do
    Asset
    |> where([a], a.workspace_id == ^workspace_id)
    |> where([a], a.attachable_type == ^attachable_type)
    |> where([a], a.attachable_id == ^attachable_id)
    |> where([a], a.status == "active")
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  # Private functions

  defp validate_attachable_ownership(workspace_id, attachable_type, attachable_id) do
    case attachable_type do
      "doc" ->
        validate_doc_ownership(workspace_id, attachable_id)

      "message" ->
        validate_message_ownership(workspace_id, attachable_id)

      "user" ->
        validate_user_ownership(workspace_id, attachable_id)

      "task" ->
        validate_task_ownership(workspace_id, attachable_id)

      "channel" ->
        validate_channel_ownership(workspace_id, attachable_id)

      "dm" ->
        validate_dm_ownership(workspace_id, attachable_id)

      "workspace" ->
        validate_workspace_ownership(workspace_id, attachable_id)

      nil ->
        {:error, :attachable_type_required}

      _ ->
        {:error, :invalid_attachable_type}
    end
  end

  defp validate_doc_ownership(workspace_id, doc_id) do
    case doc_id do
      nil ->
        {:error, :attachable_id_required}

      _ ->
        query =
          from(d in Missionspace.Docs.Doc,
            where: d.id == ^doc_id and d.workspace_id == ^workspace_id
          )

        if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
    end
  end

  defp validate_message_ownership(workspace_id, message_id) do
    case message_id do
      nil ->
        {:error, :attachable_id_required}

      _ ->
        # Messages are linked to entities (doc, channel, task, etc.)
        # We need to check if the message's entity belongs to the workspace
        query =
          from(m in Missionspace.Chat.Message,
            where: m.id == ^message_id
          )

        case Repo.one(query) do
          nil ->
            {:error, :attachable_not_found}

          message ->
            # Validate the message's entity belongs to the workspace
            validate_message_entity_ownership(
              workspace_id,
              message.entity_type,
              message.entity_id
            )
        end
    end
  end

  defp validate_message_entity_ownership(workspace_id, "doc", entity_id) do
    validate_doc_ownership(workspace_id, entity_id)
  end

  defp validate_message_entity_ownership(workspace_id, "channel", entity_id) do
    query =
      from(c in Missionspace.Chat.Channel,
        where: c.id == ^entity_id and c.workspace_id == ^workspace_id
      )

    if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
  end

  defp validate_message_entity_ownership(workspace_id, "task", entity_id) do
    query =
      from(t in Missionspace.Lists.Task,
        join: l in Missionspace.Lists.List,
        on: t.list_id == l.id,
        where: t.id == ^entity_id and l.workspace_id == ^workspace_id
      )

    if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
  end

  defp validate_message_entity_ownership(workspace_id, "dm", entity_id) do
    query =
      from(d in Missionspace.Chat.DirectMessage,
        where: d.id == ^entity_id and d.workspace_id == ^workspace_id
      )

    if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
  end

  defp validate_message_entity_ownership(_workspace_id, _entity_type, _entity_id) do
    {:error, :invalid_entity_type}
  end

  defp validate_user_ownership(workspace_id, user_id) do
    case user_id do
      nil ->
        {:error, :attachable_id_required}

      _ ->
        query =
          from(u in Missionspace.Accounts.User,
            where: u.id == ^user_id and u.workspace_id == ^workspace_id
          )

        if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
    end
  end

  defp validate_task_ownership(workspace_id, task_id) do
    case task_id do
      nil ->
        {:error, :attachable_id_required}

      _ ->
        query =
          from(t in Missionspace.Lists.Task,
            join: l in Missionspace.Lists.List,
            on: t.list_id == l.id,
            where: t.id == ^task_id and l.workspace_id == ^workspace_id
          )

        if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
    end
  end

  defp validate_channel_ownership(workspace_id, channel_id) do
    case channel_id do
      nil ->
        {:error, :attachable_id_required}

      _ ->
        query =
          from(c in Missionspace.Chat.Channel,
            where: c.id == ^channel_id and c.workspace_id == ^workspace_id
          )

        if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
    end
  end

  defp validate_workspace_ownership(workspace_id, attachable_id) do
    case attachable_id do
      nil ->
        {:error, :attachable_id_required}

      _ ->
        if attachable_id == workspace_id do
          :ok
        else
          {:error, :attachable_not_found}
        end
    end
  end

  defp validate_dm_ownership(workspace_id, dm_id) do
    case dm_id do
      nil ->
        {:error, :attachable_id_required}

      _ ->
        query =
          from(d in Missionspace.Chat.DirectMessage,
            where: d.id == ^dm_id and d.workspace_id == ^workspace_id
          )

        if Repo.exists?(query), do: :ok, else: {:error, :attachable_not_found}
    end
  end

  defp validate_file_size(size_bytes, asset_type) do
    max_size =
      case asset_type do
        "avatar" -> @max_avatar_size
        _ -> @max_file_size
      end

    if size_bytes <= max_size do
      :ok
    else
      {:error, :file_too_large}
    end
  end

  defp check_storage_quota(workspace_id, size_bytes) do
    case Repo.get(Workspace, workspace_id) do
      nil ->
        {:error, :workspace_not_found}

      workspace ->
        if workspace.storage_used_bytes + size_bytes <= workspace.storage_quota_bytes do
          :ok
        else
          {:error, :storage_quota_exceeded}
        end
    end
  end

  defp validate_pending_status(%Asset{status: "pending"}), do: :ok
  defp validate_pending_status(_), do: {:error, :invalid_status}

  defp update_asset_status(asset, status) do
    asset
    |> Asset.status_changeset(status)
    |> Repo.update()
  end

  defp increment_storage_usage(workspace_id, bytes) do
    Workspace
    |> where([w], w.id == ^workspace_id)
    |> Repo.update_all(inc: [storage_used_bytes: bytes])

    {:ok, Repo.get!(Workspace, workspace_id)}
  end

  defp decrement_storage_usage(workspace_id, bytes) do
    Workspace
    |> where([w], w.id == ^workspace_id)
    |> Repo.update_all(inc: [storage_used_bytes: -bytes])

    {:ok, Repo.get!(Workspace, workspace_id)}
  end
end
