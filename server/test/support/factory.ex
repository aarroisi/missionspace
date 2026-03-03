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
      role: "owner",
      email_verified_at: DateTime.utc_now()
    }
  end

  def project_factory do
    %Bridge.Projects.Project{
      name: Faker.Lorem.sentence(2..4),
      starred: false
    }
  end

  def doc_folder_factory do
    %Bridge.Docs.DocFolder{
      name: Faker.Lorem.sentence(2..4),
      prefix: sequence(:doc_folder_prefix, &String.upcase("D#{&1}")),
      doc_sequence_counter: 0,
      starred: false
    }
  end

  def prefix_factory do
    %Bridge.Namespaces.Prefix{
      prefix: sequence(:ns_prefix, &String.upcase("P#{&1}")),
      entity_type: "list",
      entity_id: UUIDv7.generate()
    }
  end

  def doc_factory do
    %Bridge.Docs.Doc{
      title: Faker.Lorem.sentence(3..6),
      content: Faker.Lorem.paragraph(2..5),
      starred: false,
      sequence_number: sequence(:doc_seq, & &1)
    }
  end

  def list_factory do
    %Bridge.Lists.List{
      name: Faker.Lorem.sentence(2..4),
      prefix: sequence(:prefix, &String.upcase("T#{&1}")),
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
      sequence_number: sequence(:task_seq, &(&1 + 10000)),
      notes: Faker.Lorem.paragraph(1..3),
      due_on: Date.add(Date.utc_today(), Enum.random(1..30))
    }
  end

  def channel_factory do
    %Bridge.Chat.Channel{
      name: sequence(:channel_name, &"#channel-#{&1}"),
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
      item_type: "doc_folder",
      item_id: UUIDv7.generate()
    }
  end

  def item_member_factory do
    %Bridge.Projects.ItemMember{
      item_type: "channel",
      item_id: UUIDv7.generate()
    }
  end

  def notification_factory do
    %Bridge.Notifications.Notification{
      type: "mention",
      item_type: "channel",
      item_id: UUIDv7.generate(),
      entity_type: "message",
      entity_id: UUIDv7.generate(),
      context: %{},
      read: false
    }
  end

  def subscription_factory do
    %Bridge.Subscriptions.Subscription{
      item_type: "task",
      item_id: UUIDv7.generate()
    }
  end

  def read_position_factory do
    %Bridge.Chat.ReadPosition{
      item_type: "channel",
      item_id: UUIDv7.generate(),
      last_read_at: DateTime.utc_now()
    }
  end

  def asset_factory do
    %Bridge.Assets.Asset{
      filename: sequence(:filename, &"file-#{&1}.png"),
      content_type: "image/png",
      size_bytes: Enum.random(1000..1_000_000),
      storage_key: sequence(:storage_key, &"workspace/avatar/2026/02/#{&1}.png"),
      asset_type: "avatar",
      status: "pending",
      # Default attachable - tests should override with actual item
      attachable_type: "user",
      attachable_id: nil
    }
  end
end
