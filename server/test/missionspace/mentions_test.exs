defmodule Missionspace.MentionsTest do
  use ExUnit.Case, async: true

  alias Missionspace.Mentions

  describe "extract_mention_ids/1" do
    test "extracts ids from markdown mention links" do
      content =
        "Hello @[Jane Smith](member:550e8400-e29b-41d4-a716-446655440000) and @[Alex](member:11111111-2222-3333-4444-555555555555)"

      assert Mentions.extract_mention_ids(content) == [
               "550e8400-e29b-41d4-a716-446655440000",
               "11111111-2222-3333-4444-555555555555"
             ]
    end

    test "extracts ids from legacy html mention spans" do
      content =
        ~s(<p>Hello <span class="mention" data-id="550e8400-e29b-41d4-a716-446655440000">@Jane</span></p>)

      assert Mentions.extract_mention_ids(content) == [
               "550e8400-e29b-41d4-a716-446655440000"
             ]
    end

    test "deduplicates ids across markdown and html formats" do
      id = "550e8400-e29b-41d4-a716-446655440000"

      content =
        "@[Jane](member:#{id}) <span class=\"mention\" data-id=\"#{id}\">@Jane</span> @[Jane](member:#{id})"

      assert Mentions.extract_mention_ids(content) == [id]
    end

    test "returns empty list for non-binary values" do
      assert Mentions.extract_mention_ids(nil) == []
    end
  end
end
