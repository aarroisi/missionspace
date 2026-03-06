defmodule Missionspace.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Missionspace.Repo

  alias Missionspace.Accounts.{DeviceSession, DeviceSessionAccount, User, Workspace}
  alias Missionspace.ApiKeys

  @device_account_session_max_age 1_209_600

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Returns the list of active users in a workspace.
  """
  def list_workspace_users(workspace_id) do
    User
    |> where([u], u.workspace_id == ^workspace_id and u.is_active == true)
    |> order_by([u], desc: u.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a user within a workspace.
  Returns `{:ok, user}` if found, `{:error, :not_found}` otherwise.
  """
  def get_workspace_user(id, workspace_id) do
    case User
         |> where([u], u.workspace_id == ^workspace_id)
         |> Repo.get(id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Gets a single user.

  Returns `{:ok, user}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_user(123)
      {:ok, %User{}}

      iex> get_user(456)
      {:error, :not_found}

  """
  def get_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Gets a single user by email.

  Returns `nil` if the User does not exist.

  ## Examples

      iex> get_user_by_email("user@example.com")
      %User{}

      iex> get_user_by_email("nonexistent@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    changeset = User.changeset(user, attrs)
    new_role = Ecto.Changeset.get_change(changeset, :role)

    if is_binary(new_role) do
      Repo.transaction(fn ->
        case Repo.update(changeset) do
          {:ok, updated_user} ->
            maybe_force_private_items_to_shared(user, new_role)

            case ApiKeys.reconcile_scopes_for_user_role(updated_user.id, updated_user.role) do
              {:ok, _updated_count} -> updated_user
              {:error, reason} -> Repo.rollback(reason)
            end

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    else
      Repo.update(changeset)
    end
  end

  defp maybe_force_private_items_to_shared(%User{role: "owner", id: user_id}, new_role)
       when new_role in ["member", "guest"] do
    force_private_items_to_shared(user_id)
  end

  defp maybe_force_private_items_to_shared(_user, _new_role), do: :ok

  defp force_private_items_to_shared(user_id) do
    import Ecto.Query

    from(l in Missionspace.Lists.List,
      where: l.created_by_id == ^user_id and l.visibility == "private"
    )
    |> Repo.update_all(set: [visibility: "shared"])

    from(f in Missionspace.Docs.DocFolder,
      where: f.created_by_id == ^user_id and f.visibility == "private"
    )
    |> Repo.update_all(set: [visibility: "shared"])

    from(c in Missionspace.Chat.Channel,
      where: c.created_by_id == ^user_id and c.visibility == "private"
    )
    |> Repo.update_all(set: [visibility: "shared"])
  end

  @doc """
  Soft-deletes a user by marking them as inactive and scrubbing their email.
  Also removes their project memberships and notifications.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    alias Missionspace.Projects
    alias Missionspace.Notifications

    Repo.transaction(fn ->
      # Remove project memberships
      Projects.remove_all_memberships_for_user(user.id)

      # Remove item memberships
      Projects.remove_all_item_memberships_for_user(user.id)

      # Remove notifications (both as recipient and actor)
      Notifications.delete_all_for_user(user.id)

      # Remove subscriptions
      Missionspace.Subscriptions.delete_all_for_user(user.id)

      # Remove API keys
      ApiKeys.delete_all_for_user(user.id)

      # Scrub email and soft-delete user
      scrubbed_email = "deleted_#{user.id}@deleted.local"

      case user
           |> User.changeset(%{
             is_active: false,
             deleted_at: DateTime.utc_now(),
             email: scrubbed_email
           })
           |> Repo.update() do
        {:ok, updated_user} -> updated_user
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Returns the list of online users.

  ## Examples

      iex> list_online_users()
      [%User{}, ...]

  """
  def list_online_users do
    User
    |> where([u], u.online == true)
    |> Repo.all()
  end

  @doc """
  Sets a user's online status.

  ## Examples

      iex> set_user_online_status(user, true)
      {:ok, %User{}}

  """
  def set_user_online_status(%User{} = user, online) when is_boolean(online) do
    update_user(user, %{online: online})
  end

  # Workspace functions

  @doc """
  Gets a single workspace.

  Returns `{:ok, workspace}` if found, `{:error, :not_found}` otherwise.

  ## Examples

      iex> get_workspace(123)
      {:ok, %Workspace{}}

      iex> get_workspace(456)
      {:error, :not_found}

  """
  def get_workspace(id) do
    case Repo.get(Workspace, id) do
      nil -> {:error, :not_found}
      workspace -> {:ok, workspace}
    end
  end

  def get_workspace_by_slug(slug), do: Repo.get_by(Workspace, slug: slug)

  def create_workspace(attrs) do
    %Workspace{}
    |> Workspace.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  # Authentication functions

  @doc """
  Registers a new workspace with the first user.
  Returns {:ok, %{workspace: workspace, user: user}} or {:error, changeset}
  """
  def register_workspace_and_user(workspace_name, user_name, email, password) do
    result =
      Repo.transaction(fn ->
        # Create workspace
        workspace_attrs = %{name: workspace_name, slug: slugify(workspace_name)}

        case create_workspace(workspace_attrs) do
          {:ok, workspace} ->
            # Create first user
            user_attrs = %{
              name: user_name,
              email: email,
              password: password,
              workspace_id: workspace.id
            }

            case %User{}
                 |> User.registration_changeset(user_attrs)
                 |> Repo.insert() do
              {:ok, user} ->
                %{workspace: workspace, user: user}

              {:error, changeset} ->
                Repo.rollback(changeset)
            end

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)

    # Send verification email after successful registration
    case result do
      {:ok, %{user: user}} ->
        Missionspace.Emails.verification_email(user) |> Missionspace.Mailer.deliver()
        result

      _ ->
        result
    end
  end

  @doc """
  Authenticates a user by email and password.
  Returns {:ok, user} or {:error, :invalid_credentials}
  Only active users can authenticate.
  """
  def authenticate_user(email, password) do
    user =
      User
      |> where([u], u.email == ^email and u.is_active == true)
      |> Repo.one()
      |> Repo.preload(:workspace)

    if user && User.verify_password(user, password) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc """
  Returns an existing device session for a cookie token or creates a new one.
  """
  def ensure_device_session(device_token \\ nil)

  def ensure_device_session(device_token) when is_binary(device_token) do
    case get_device_session_by_token(device_token) do
      {:ok, device_session} ->
        touch_device_session(device_session)
        {:ok, %{device_session: device_session, token: device_token, created?: false}}

      {:error, :not_found} ->
        create_device_session()
    end
  end

  def ensure_device_session(_), do: create_device_session()

  def get_device_session(device_token) when is_binary(device_token) do
    get_device_session_by_token(device_token)
  end

  def get_device_session(_), do: {:error, :not_found}

  @doc """
  Lists remembered accounts for a device token.
  """
  def list_device_accounts(device_token, current_device_account_id \\ nil)

  def list_device_accounts(device_token, current_device_account_id)
      when is_binary(device_token) do
    with {:ok, device_session} <- get_device_session_by_token(device_token) do
      touch_device_session(device_session)

      account_summaries =
        device_session_accounts_query(device_session.id)
        |> Repo.all()
        |> Enum.reduce([], fn account, summaries ->
          case normalize_device_account(account) do
            {:ok, normalized_account, state} ->
              [
                device_account_summary(normalized_account, state, current_device_account_id)
                | summaries
              ]

            {:error, :not_available} ->
              _ = Repo.delete(account)
              summaries
          end
        end)
        |> Enum.reverse()

      {:ok, account_summaries}
    else
      {:error, :not_found} -> {:ok, []}
    end
  end

  def list_device_accounts(_, _), do: {:ok, []}

  @doc """
  Authenticates the current session against a device account token.
  """
  def authenticate_device_account_session(device_token, device_account_id, session_token)
      when is_binary(device_token) and is_binary(device_account_id) and is_binary(session_token) do
    with {:ok, device_session} <- get_device_session_by_token(device_token),
         %DeviceSessionAccount{} = account <-
           get_device_account(device_session.id, device_account_id),
         {:ok, normalized_account, "available"} <- normalize_device_account(account),
         true <- token_matches?(normalized_account, session_token) do
      {:ok, normalized_account}
    else
      nil -> {:error, :not_found}
      false -> {:error, :signed_out}
      {:ok, _normalized_account, "signed_out"} -> {:error, :signed_out}
      {:error, :not_available} -> {:error, :not_found}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def authenticate_device_account_session(_, _, _), do: {:error, :not_found}

  @doc """
  Remembers an account on a device and marks it available.
  """
  def remember_device_account(%DeviceSession{} = device_session, %User{} = user) do
    issue_device_account_session(device_session, user)
  end

  @doc """
  Switches to an available remembered account on a device.
  """
  def switch_device_account(%DeviceSession{} = device_session, user_id) when is_binary(user_id) do
    case Repo.get_by(DeviceSessionAccount, device_session_id: device_session.id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      account ->
        case normalize_device_account(account) do
          {:ok, _account, "signed_out"} ->
            {:error, :reauth_required}

          {:ok, normalized_account, "available"} ->
            issue_device_account_session(
              device_session,
              normalized_account.user,
              normalized_account
            )

          {:error, :not_available} ->
            {:error, :not_found}
        end
    end
  end

  @doc """
  Signs out the remembered account on a device without removing it.
  """
  def sign_out_device_account(%DeviceSession{} = device_session, user_id)
      when is_binary(user_id) do
    case Repo.get_by(DeviceSessionAccount, device_session_id: device_session.id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      account ->
        account
        |> DeviceSessionAccount.changeset(%{
          session_token_hash: nil,
          session_token_expires_at: nil,
          signed_out_at: DateTime.utc_now()
        })
        |> Repo.update()
        |> case do
          {:ok, updated_account} ->
            {:ok, preload_device_account(updated_account), "signed_out"}

          error ->
            error
        end
    end
  end

  @doc """
  Removes a remembered account from the device.
  """
  def remove_device_account(%DeviceSession{} = device_session, user_id) when is_binary(user_id) do
    case Repo.get_by(DeviceSessionAccount, device_session_id: device_session.id, user_id: user_id) do
      nil -> {:error, :not_found}
      account -> Repo.delete(account)
    end
  end

  @doc """
  Reauthenticates a signed-out remembered account and issues a fresh account session.
  """
  def reauthenticate_device_account(%DeviceSession{} = device_session, user_id, password)
      when is_binary(user_id) and is_binary(password) do
    with %DeviceSessionAccount{} = account <-
           Repo.get_by(DeviceSessionAccount,
             device_session_id: device_session.id,
             user_id: user_id
           ),
         {:ok, user} <- get_user(user_id),
         true <- User.verify_password(user, password) do
      issue_device_account_session(device_session, user, account)
    else
      nil -> {:error, :not_found}
      false -> {:error, :invalid_credentials}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  def device_account_summary(%DeviceSessionAccount{} = account, state, current_device_account_id) do
    %{
      user: %{account.user | password_hash: nil},
      workspace: account.user.workspace,
      current: state == "available" and account.id == current_device_account_id,
      state: state
    }
  end

  # Email verification

  def verify_email(token) when is_binary(token) do
    case Repo.get_by(User, email_verification_token: token) do
      nil ->
        {:error, :invalid_token}

      user ->
        user
        |> Ecto.Changeset.change(%{
          email_verified_at: DateTime.utc_now(),
          email_verification_token: nil
        })
        |> Repo.update()
    end
  end

  def resend_verification_email(%User{} = user) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    case user
         |> Ecto.Changeset.change(%{email_verification_token: token})
         |> Repo.update() do
      {:ok, updated_user} ->
        Missionspace.Emails.verification_email(updated_user) |> Missionspace.Mailer.deliver()
        {:ok, updated_user}

      error ->
        error
    end
  end

  # Password reset

  def request_password_reset(email) when is_binary(email) do
    case get_user_by_email(email) do
      nil ->
        # Don't reveal whether email exists
        :ok

      user ->
        changeset = User.password_reset_changeset(user)

        case Repo.update(changeset) do
          {:ok, updated_user} ->
            Missionspace.Emails.password_reset_email(updated_user)
            |> Missionspace.Mailer.deliver()

            :ok

          _ ->
            :ok
        end
    end
  end

  def reset_password(token, new_password) when is_binary(token) do
    case Repo.get_by(User, password_reset_token: token) do
      nil ->
        {:error, :invalid_token}

      user ->
        if user.password_reset_expires_at &&
             DateTime.compare(DateTime.utc_now(), user.password_reset_expires_at) == :lt do
          user
          |> User.reset_password_changeset(%{password: new_password})
          |> Repo.update()
        else
          {:error, :token_expired}
        end
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp create_device_session do
    token = generate_token()

    %DeviceSession{}
    |> DeviceSession.create_changeset(%{
      token_hash: hash_token(token),
      last_seen_at: DateTime.utc_now()
    })
    |> Repo.insert()
    |> case do
      {:ok, device_session} ->
        {:ok, %{device_session: device_session, token: token, created?: true}}

      error ->
        error
    end
  end

  defp get_device_session_by_token(device_token) do
    case Repo.get_by(DeviceSession, token_hash: hash_token(device_token)) do
      nil -> {:error, :not_found}
      device_session -> {:ok, device_session}
    end
  end

  defp touch_device_session(%DeviceSession{} = device_session) do
    device_session
    |> DeviceSession.touch_changeset()
    |> Repo.update()
  end

  defp device_session_accounts_query(device_session_id) do
    from(account in DeviceSessionAccount,
      where: account.device_session_id == ^device_session_id,
      order_by: [desc: account.last_used_at, desc: account.inserted_at],
      preload: [user: :workspace]
    )
  end

  defp get_device_account(device_session_id, device_account_id) do
    DeviceSessionAccount
    |> where(
      [account],
      account.device_session_id == ^device_session_id and account.id == ^device_account_id
    )
    |> preload(user: :workspace)
    |> Repo.one()
  end

  defp preload_device_account(%DeviceSessionAccount{} = account) do
    Repo.preload(account, user: :workspace)
  end

  defp normalize_device_account(%DeviceSessionAccount{} = account) do
    account = preload_device_account(account)
    user = account.user

    cond do
      is_nil(user) ->
        {:error, :not_available}

      not user.is_active ->
        {:error, :not_available}

      is_nil(user.email_verified_at) ->
        {:error, :not_available}

      is_nil(user.workspace) ->
        {:error, :not_available}

      account_expired?(account) ->
        {:ok, expire_device_account(account), "signed_out"}

      is_nil(account.session_token_hash) or not is_nil(account.signed_out_at) ->
        {:ok, account, "signed_out"}

      true ->
        {:ok, account, "available"}
    end
  end

  defp expire_device_account(%DeviceSessionAccount{} = account) do
    {:ok, updated_account} =
      account
      |> DeviceSessionAccount.changeset(%{
        session_token_hash: nil,
        session_token_expires_at: nil,
        signed_out_at: account.signed_out_at || DateTime.utc_now()
      })
      |> Repo.update()

    preload_device_account(updated_account)
  end

  defp issue_device_account_session(
         %DeviceSession{} = device_session,
         %User{} = user,
         account \\ nil
       ) do
    account =
      account ||
        Repo.get_by(DeviceSessionAccount, device_session_id: device_session.id, user_id: user.id)

    session_token = generate_token()
    now = DateTime.utc_now()

    attrs = %{
      device_session_id: device_session.id,
      user_id: user.id,
      session_token_hash: hash_token(session_token),
      session_token_expires_at: DateTime.add(now, @device_account_session_max_age, :second),
      signed_out_at: nil,
      last_used_at: now,
      last_authenticated_at: now
    }

    changeset =
      case account do
        %DeviceSessionAccount{} = existing_account ->
          DeviceSessionAccount.changeset(existing_account, attrs)

        nil ->
          DeviceSessionAccount.changeset(%DeviceSessionAccount{}, attrs)
      end

    case Repo.insert_or_update(changeset) do
      {:ok, updated_account} ->
        {:ok,
         %{device_account: preload_device_account(updated_account), session_token: session_token}}

      error ->
        error
    end
  end

  defp token_matches?(%DeviceSessionAccount{} = account, session_token) do
    account.session_token_hash == hash_token(session_token)
  end

  defp account_expired?(%DeviceSessionAccount{session_token_expires_at: nil}), do: false

  defp account_expired?(%DeviceSessionAccount{session_token_expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end
end
