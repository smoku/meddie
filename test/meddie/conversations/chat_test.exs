defmodule Meddie.Conversations.ChatTest do
  use Meddie.DataCase

  alias Meddie.Conversations.Chat

  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.ConversationsFixtures

  describe "parse_memory_updates/1" do
    test "parses memory updates from code-fenced JSON block" do
      text = """
      Here is some response text.

      ```json
      {"memory_updates": [{"field": "health_notes", "action": "append", "text": "Hypothyroidism"}]}
      ```
      """

      {display_text, updates} = Chat.parse_memory_updates(text)

      assert String.trim(display_text) == "Here is some response text."
      assert length(updates) == 1
      assert hd(updates)["field"] == "health_notes"
      assert hd(updates)["action"] == "append"
      assert hd(updates)["text"] == "Hypothyroidism"
    end

    test "parses memory updates from unfenced JSON block" do
      text = ~s|Some text.\n{"memory_updates": [{"field": "medications", "action": "append", "text": "Aspirin"}]}|

      {display_text, updates} = Chat.parse_memory_updates(text)

      assert String.trim(display_text) == "Some text."
      assert length(updates) == 1
      assert hd(updates)["field"] == "medications"
    end

    test "returns empty list when no memory updates present" do
      text = "Just a regular response with no updates."

      {display_text, updates} = Chat.parse_memory_updates(text)

      assert display_text == text
      assert updates == []
    end

    test "returns empty list for invalid JSON" do
      text = "Some text.\n```json\n{not valid json}\n```"

      {_display_text, updates} = Chat.parse_memory_updates(text)

      assert updates == []
    end
  end

  describe "apply_field_update/3" do
    test "append to nil value" do
      assert Chat.apply_field_update(nil, "append", "New item") == "New item"
    end

    test "append to empty string" do
      assert Chat.apply_field_update("", "append", "New item") == "New item"
    end

    test "append to existing value" do
      assert Chat.apply_field_update("Existing", "append", "New") == "Existing\nNew"
    end

    test "remove from nil" do
      assert Chat.apply_field_update(nil, "remove", "anything") == nil
    end

    test "remove from empty string" do
      assert Chat.apply_field_update("", "remove", "anything") == ""
    end

    test "remove matching line" do
      current = "Line one\nRemove me\nLine three"
      result = Chat.apply_field_update(current, "remove", "Remove me")
      assert result == "Line one\nLine three"
    end

    test "remove with partial match" do
      current = "Takes Aspirin daily\nNo allergies"
      result = Chat.apply_field_update(current, "remove", "Aspirin")
      assert result == "No allergies"
    end
  end

  describe "apply_memory_updates/5" do
    test "returns empty list when updates is empty" do
      assert Chat.apply_memory_updates(nil, nil, nil, nil, []) == []
    end

    test "returns empty list when person is nil" do
      assert Chat.apply_memory_updates(nil, nil, nil, nil, [%{"field" => "health_notes"}]) == []
    end

    test "applies valid memory update and creates system message", %{} do
      %{scope: scope} = user_with_space_fixture(%{locale: "en"})
      person = person_fixture(scope, %{"name" => "Test Person"})
      conv = conversation_fixture(scope, %{"person_id" => person.id})
      msg = message_fixture(conv, %{"role" => "assistant", "content" => "Noted."})

      updates = [
        %{"field" => "health_notes", "action" => "append", "text" => "Hypothyroidism diagnosed"}
      ]

      system_messages = Chat.apply_memory_updates(scope, conv, person, msg, updates)

      assert length(system_messages) == 1
      assert hd(system_messages).role == "system"
      assert hd(system_messages).content =~ "Hypothyroidism diagnosed"

      # Verify person was updated
      updated_person = Meddie.People.get_person!(scope, person.id)
      assert updated_person.health_notes =~ "Hypothyroidism diagnosed"
    end

    test "ignores updates for invalid fields" do
      %{scope: scope} = user_with_space_fixture(%{locale: "en"})
      person = person_fixture(scope, %{"name" => "Test Person"})
      conv = conversation_fixture(scope, %{"person_id" => person.id})
      msg = message_fixture(conv, %{"role" => "assistant", "content" => "Noted."})

      updates = [
        %{"field" => "invalid_field", "action" => "append", "text" => "something"}
      ]

      system_messages = Chat.apply_memory_updates(scope, conv, person, msg, updates)
      assert system_messages == []
    end
  end

  describe "resolve_person/3" do
    test "returns nil when no people" do
      assert Chat.resolve_person("Hello", [], nil) == nil
    end

    test "returns the single person when only one exists" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope, %{"name" => "Only Person"})

      assert Chat.resolve_person("Hello", [person], scope) == person
    end

    test "resolves via AI when multiple people exist" do
      %{scope: scope} = user_with_space_fixture()
      person1 = person_fixture(scope, %{"name" => "Anna Kowalska"})
      person2 = person_fixture(scope, %{"name" => "Jan Nowak"})

      # Mock returns person_number 1
      result = Chat.resolve_person("Tell me about Anna", [person1, person2], scope)
      assert result == person1
    end
  end

  describe "split_message/2" do
    test "returns single chunk for short messages" do
      assert Chat.split_message("Hello") == ["Hello"]
    end

    test "splits long message into chunks" do
      # Create a message longer than 50 chars
      text = String.duplicate("a", 30) <> "\n\n" <> String.duplicate("b", 30)
      chunks = Chat.split_message(text, 50)

      assert length(chunks) == 2
      assert Enum.all?(chunks, fn c -> String.length(c) <= 50 end)
    end

    test "uses default max_length of 4096" do
      short = "Hello world"
      assert Chat.split_message(short) == [short]
    end
  end

  describe "prepare_ai_messages/1" do
    test "filters out system messages" do
      messages = [
        %{role: "user", content: "Hello"},
        %{role: "assistant", content: "Hi"},
        %{role: "system", content: "System note"},
        %{role: "user", content: "Question"}
      ]

      result = Chat.prepare_ai_messages(messages)
      assert length(result) == 3
      assert Enum.all?(result, fn m -> m.role in ["user", "assistant"] end)
    end

    test "limits to last N messages" do
      messages = Enum.map(1..25, fn i ->
        %{role: if(rem(i, 2) == 0, do: "assistant", else: "user"), content: "Message #{i}"}
      end)

      result = Chat.prepare_ai_messages(messages)
      # @max_ai_messages is 20
      assert length(result) == 20
    end
  end
end
