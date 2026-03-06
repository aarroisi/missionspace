# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Missionspace.Repo.insert!(%Missionspace.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Missionspace.Repo
alias Missionspace.Accounts
alias Missionspace.Projects
alias Missionspace.Lists
alias Missionspace.Docs
alias Missionspace.Chat

# Clean database
Repo.delete_all(Missionspace.Chat.Message)
Repo.delete_all(Missionspace.Lists.Subtask)
Repo.delete_all(Missionspace.Lists.Task)
Repo.delete_all(Missionspace.Lists.List)
Repo.delete_all(Missionspace.Docs.Doc)
Repo.delete_all(Missionspace.Chat.Channel)
Repo.delete_all(Missionspace.Chat.DirectMessage)
Repo.delete_all(Missionspace.Projects.Project)
Repo.delete_all(Missionspace.Accounts.User)

# Create users
{:ok, user1} =
  Accounts.create_user(%{
    name: "Alex Kim",
    email: "alex@missionspace.app",
    avatar: "AK",
    online: true
  })

{:ok, user2} =
  Accounts.create_user(%{
    name: "Morgan Jones",
    email: "morgan@missionspace.app",
    avatar: "MJ",
    online: true
  })

{:ok, user3} =
  Accounts.create_user(%{
    name: "Sam Rivera",
    email: "sam@missionspace.app",
    avatar: "SR",
    online: false
  })

IO.puts("Created #{Enum.count(Accounts.list_users())} users")

# Create projects
{:ok, project1} =
  Projects.create_project(%{
    name: "Product Launch",
    starred: true
  })

{:ok, project2} =
  Projects.create_project(%{
    name: "Website Redesign",
    starred: false
  })

IO.puts("Created #{Enum.count(Projects.list_projects())} projects")

# Create lists
{:ok, list1} =
  Lists.create_list(%{
    name: "Sprint Tasks",
    project_id: project1.id,
    starred: true
  })

{:ok, list2} =
  Lists.create_list(%{
    name: "Design Tasks",
    starred: false
  })

IO.puts("Created #{Enum.count(Lists.list_lists())} lists")

# Create tasks
{:ok, task1} =
  Lists.create_task(%{
    title: "Design new homepage",
    status: "doing",
    notes: "Focus on mobile-first approach",
    list_id: list1.id,
    assignee_id: user1.id,
    created_by_id: user2.id,
    due_on: Date.add(Date.utc_today(), 7)
  })

{:ok, task2} =
  Lists.create_task(%{
    title: "Implement authentication",
    status: "todo",
    list_id: list1.id,
    created_by_id: user1.id,
    due_on: Date.add(Date.utc_today(), 14)
  })

{:ok, task3} =
  Lists.create_task(%{
    title: "Write user documentation",
    status: "done",
    list_id: list1.id,
    assignee_id: user3.id,
    created_by_id: user2.id
  })

IO.puts("Created #{Enum.count(Lists.list_tasks(list1.id))} tasks")

# Create subtasks
{:ok, _subtask1} =
  Lists.create_subtask(%{
    title: "Create wireframes",
    status: "done",
    task_id: task1.id,
    created_by_id: user1.id
  })

{:ok, _subtask2} =
  Lists.create_subtask(%{
    title: "Design hero section",
    status: "doing",
    task_id: task1.id,
    assignee_id: user1.id,
    created_by_id: user2.id
  })

IO.puts("Created subtasks")

# Create docs
{:ok, doc1} =
  Docs.create_doc(%{
    title: "Product Requirements",
    content:
      "<h2>Overview</h2><p>This document outlines the product requirements for our upcoming launch.</p>",
    project_id: project1.id,
    author_id: user2.id,
    starred: true
  })

{:ok, doc2} =
  Docs.create_doc(%{
    title: "Design System",
    content: "<h2>Colors</h2><p>Primary: #0f172a</p><p>Accent: #3b82f6</p>",
    author_id: user1.id,
    starred: false
  })

IO.puts("Created #{Enum.count(Docs.list_docs())} docs")

# Create channels
{:ok, channel1} =
  Chat.create_channel(%{
    name: "general",
    project_id: project1.id,
    starred: true
  })

{:ok, channel2} =
  Chat.create_channel(%{
    name: "design",
    starred: false
  })

IO.puts("Created #{Enum.count(Chat.list_channels())} channels")

# Create direct messages
{:ok, dm1} =
  Chat.create_direct_message(%{
    user1_id: user1.id,
    user2_id: user2.id,
    starred: false
  })

IO.puts("Created direct messages")

# Create messages
{:ok, message1} =
  Chat.create_message(%{
    text: "Hey team, let's discuss the new design direction",
    entity_type: "channel",
    entity_id: channel1.id,
    user_id: user1.id
  })

{:ok, _reply1} =
  Chat.create_message(%{
    text: "Sounds good! I have some ideas to share",
    entity_type: "channel",
    entity_id: channel1.id,
    user_id: user2.id,
    parent_id: message1.id
  })

{:ok, message2} =
  Chat.create_message(%{
    text: "Great work on the wireframes!",
    entity_type: "task",
    entity_id: task1.id,
    user_id: user2.id
  })

{:ok, _message3} =
  Chat.create_message(%{
    text: "The product requirements doc looks comprehensive",
    entity_type: "doc",
    entity_id: doc1.id,
    user_id: user1.id
  })

IO.puts("Created messages and comments")

IO.puts("\n✅ Database seeded successfully!")
IO.puts("\nYou can now:")
IO.puts("  • Start the server: mix phx.server")
IO.puts("  • Access API at: http://localhost:4000/api")
IO.puts("  • WebSocket at: ws://localhost:4000/socket")
