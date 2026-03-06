defmodule Missionspace.Repo.Migrations.ChangeUserFkToRestrict do
  use Ecto.Migration

  def up do
    # Tasks - assignee_id and created_by_id
    drop(constraint(:tasks, "tasks_assignee_id_fkey"))
    drop(constraint(:tasks, "tasks_created_by_id_fkey"))

    alter table(:tasks) do
      modify(:assignee_id, references(:users, type: :binary_id, on_delete: :restrict))
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Subtasks - assignee_id and created_by_id
    drop(constraint(:subtasks, "subtasks_assignee_id_fkey"))
    drop(constraint(:subtasks, "subtasks_created_by_id_fkey"))

    alter table(:subtasks) do
      modify(:assignee_id, references(:users, type: :binary_id, on_delete: :restrict))
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Docs - author_id
    drop(constraint(:docs, "docs_author_id_fkey"))

    alter table(:docs) do
      modify(:author_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Messages - user_id
    drop(constraint(:messages, "messages_user_id_fkey"))

    alter table(:messages) do
      modify(:user_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Direct Messages - user1_id and user2_id
    drop(constraint(:direct_messages, "direct_messages_user1_id_fkey"))
    drop(constraint(:direct_messages, "direct_messages_user2_id_fkey"))

    alter table(:direct_messages) do
      modify(:user1_id, references(:users, type: :binary_id, on_delete: :restrict))
      modify(:user2_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Project Members - user_id
    drop(constraint(:project_members, "project_members_user_id_fkey"))

    alter table(:project_members) do
      modify(:user_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Projects - created_by_id
    drop(constraint(:projects, "projects_created_by_id_fkey"))

    alter table(:projects) do
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Lists - created_by_id
    drop(constraint(:lists, "lists_created_by_id_fkey"))

    alter table(:lists) do
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Channels - created_by_id
    drop(constraint(:channels, "channels_created_by_id_fkey"))

    alter table(:channels) do
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :restrict))
    end

    # Notifications - user_id and actor_id
    drop(constraint(:notifications, "notifications_user_id_fkey"))
    drop(constraint(:notifications, "notifications_actor_id_fkey"))

    alter table(:notifications) do
      modify(:user_id, references(:users, type: :binary_id, on_delete: :restrict))
      modify(:actor_id, references(:users, type: :binary_id, on_delete: :restrict))
    end
  end

  def down do
    # Revert to original constraints
    # Tasks
    drop(constraint(:tasks, "tasks_assignee_id_fkey"))
    drop(constraint(:tasks, "tasks_created_by_id_fkey"))

    alter table(:tasks) do
      modify(:assignee_id, references(:users, type: :binary_id, on_delete: :nilify_all))
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    # Subtasks
    drop(constraint(:subtasks, "subtasks_assignee_id_fkey"))
    drop(constraint(:subtasks, "subtasks_created_by_id_fkey"))

    alter table(:subtasks) do
      modify(:assignee_id, references(:users, type: :binary_id, on_delete: :nilify_all))
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    # Docs
    drop(constraint(:docs, "docs_author_id_fkey"))

    alter table(:docs) do
      modify(:author_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    # Messages
    drop(constraint(:messages, "messages_user_id_fkey"))

    alter table(:messages) do
      modify(:user_id, references(:users, type: :binary_id, on_delete: :delete_all))
    end

    # Direct Messages
    drop(constraint(:direct_messages, "direct_messages_user1_id_fkey"))
    drop(constraint(:direct_messages, "direct_messages_user2_id_fkey"))

    alter table(:direct_messages) do
      modify(:user1_id, references(:users, type: :binary_id, on_delete: :delete_all))
      modify(:user2_id, references(:users, type: :binary_id, on_delete: :delete_all))
    end

    # Project Members
    drop(constraint(:project_members, "project_members_user_id_fkey"))

    alter table(:project_members) do
      modify(:user_id, references(:users, type: :binary_id, on_delete: :delete_all))
    end

    # Projects
    drop(constraint(:projects, "projects_created_by_id_fkey"))

    alter table(:projects) do
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    # Lists
    drop(constraint(:lists, "lists_created_by_id_fkey"))

    alter table(:lists) do
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    # Channels
    drop(constraint(:channels, "channels_created_by_id_fkey"))

    alter table(:channels) do
      modify(:created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all))
    end

    # Notifications
    drop(constraint(:notifications, "notifications_user_id_fkey"))
    drop(constraint(:notifications, "notifications_actor_id_fkey"))

    alter table(:notifications) do
      modify(:user_id, references(:users, type: :binary_id, on_delete: :delete_all))
      modify(:actor_id, references(:users, type: :binary_id, on_delete: :delete_all))
    end
  end
end
