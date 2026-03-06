defmodule Missionspace.Repo.Migrations.AddTitleLengthConstraints do
  use Ecto.Migration

  def change do
    # Add check constraints to limit title/name length to 100 characters
    create(constraint(:docs, :title_length, check: "char_length(title) <= 100"))
    create(constraint(:lists, :name_length, check: "char_length(name) <= 100"))
    create(constraint(:channels, :name_length, check: "char_length(name) <= 100"))
    create(constraint(:projects, :name_length, check: "char_length(name) <= 100"))
    create(constraint(:tasks, :title_length, check: "char_length(title) <= 100"))
  end
end
