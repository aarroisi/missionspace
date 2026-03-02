defmodule Bridge.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Bridge.Repo

  alias Bridge.Accounts.{User, Workspace}

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

    if user.role == "owner" and new_role in ["member", "guest"] do
      # Demotion: force all private items to shared
      Repo.transaction(fn ->
        case Repo.update(changeset) do
          {:ok, updated_user} ->
            force_private_items_to_shared(user.id)
            updated_user

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    else
      Repo.update(changeset)
    end
  end

  defp force_private_items_to_shared(user_id) do
    import Ecto.Query

    from(l in Bridge.Lists.List,
      where: l.created_by_id == ^user_id and l.visibility == "private"
    )
    |> Repo.update_all(set: [visibility: "shared"])

    from(f in Bridge.Docs.DocFolder,
      where: f.created_by_id == ^user_id and f.visibility == "private"
    )
    |> Repo.update_all(set: [visibility: "shared"])

    from(c in Bridge.Chat.Channel,
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
    alias Bridge.Projects
    alias Bridge.Notifications

    Repo.transaction(fn ->
      # Remove project memberships
      Projects.remove_all_memberships_for_user(user.id)

      # Remove item memberships
      Projects.remove_all_item_memberships_for_user(user.id)

      # Remove notifications (both as recipient and actor)
      Notifications.delete_all_for_user(user.id)

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

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
