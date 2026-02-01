defmodule Bridge.Factory do
  use ExMachina.Ecto, repo: Bridge.Repo

  def workspace_factory do
    %Bridge.Accounts.Workspace{
      name: Faker.Company.name(),
      slug: sequence(:slug, &"workspace-#{&1}")
    }
  end

  def user_factory do
    %Bridge.Accounts.User{
      name: Faker.Person.name(),
      email: sequence(:email, &"user-#{&1}@example.com"),
      password_hash: Bridge.Accounts.User.hash_password("password123"),
      role: "owner"
    }
  end

  def project_factory do
    %Bridge.Projects.Project{
      name: Faker.Lorem.sentence(2..4),
      starred: false
    }
  end

  def doc_factory do
    %Bridge.Docs.Doc{
      title: Faker.Lorem.sentence(3..6),
      content: Faker.Lorem.paragraph(2..5),
      starred: false
    }
  end

  def list_factory do
    %Bridge.Lists.List{
      name: Faker.Lorem.sentence(2..4),
      starred: false
    }
  end

  def list_status_factory do
    %Bridge.Lists.ListStatus{
      name: sequence(:status_name, &"status-#{&1}"),
      color: "#6b7280",
      position: 0
    }
  end

  def task_factory do
    %Bridge.Lists.Task{
      title: Faker.Lorem.sentence(3..6),
      notes: Faker.Lorem.paragraph(1..3),
      due_on: Date.add(Date.utc_today(), Enum.random(1..30))
    }
  end

  def subtask_factory do
    %Bridge.Lists.Subtask{
      title: Faker.Lorem.sentence(2..4),
      is_completed: false,
      notes: Faker.Lorem.sentence(1..2)
    }
  end

  def channel_factory do
    %Bridge.Chat.Channel{
      name: "#" <> Faker.Lorem.word(),
      starred: false
    }
  end

  def direct_message_factory do
    %Bridge.Chat.DirectMessage{}
  end

  def message_factory do
    %Bridge.Chat.Message{
      text: Faker.Lorem.sentence(5..15),
      entity_type: "channel",
      entity_id: UUIDv7.generate()
    }
  end

  def project_member_factory do
    %Bridge.Projects.ProjectMember{}
  end

  def project_item_factory do
    %Bridge.Projects.ProjectItem{
      item_type: "doc",
      item_id: UUIDv7.generate()
    }
  end

  def notification_factory do
    %Bridge.Notifications.Notification{
      type: "mention",
      entity_type: "message",
      entity_id: UUIDv7.generate(),
      context: %{},
      read: false
    }
  end
end
