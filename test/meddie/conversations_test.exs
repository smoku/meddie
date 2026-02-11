defmodule Meddie.ConversationsTest do
  use Meddie.DataCase

  alias Meddie.Conversations

  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.ConversationsFixtures

  setup do
    %{scope: scope} = fixture = user_with_space_fixture()
    person = person_fixture(scope)
    Map.merge(fixture, %{person: person})
  end

  describe "list_conversations/1" do
    test "returns conversations for current user in scope", %{scope: scope, person: person} do
      conv1 = conversation_fixture(scope, %{"person_id" => person.id})
      conv2 = conversation_fixture(scope)

      conversations = Conversations.list_conversations(scope)
      ids = Enum.map(conversations, & &1.id)

      assert length(ids) == 2
      assert conv1.id in ids
      assert conv2.id in ids
    end

    test "does not return other user's conversations", %{scope: scope} do
      _my_conv = conversation_fixture(scope)

      %{scope: other_scope} = user_with_space_fixture()
      _other_conv = conversation_fixture(other_scope)

      conversations = Conversations.list_conversations(scope)
      assert length(conversations) == 1
    end

    test "returns conversations ordered by updated_at desc", %{scope: scope} do
      conv1 = conversation_fixture(scope)
      # Update conv1's title to bump updated_at later than conv2
      conv2 = conversation_fixture(scope)
      Process.sleep(1100)
      {:ok, conv1} = Conversations.update_conversation(conv1, %{"title" => "Updated"})

      conversations = Conversations.list_conversations(scope)
      assert hd(conversations).id == conv1.id
      assert List.last(conversations).id == conv2.id
    end
  end

  describe "get_conversation!/2" do
    test "returns conversation with messages preloaded", %{scope: scope, person: person} do
      conv = conversation_fixture(scope, %{"person_id" => person.id})
      _msg1 = message_fixture(conv, %{"role" => "user", "content" => "Hello"})
      _msg2 = message_fixture(conv, %{"role" => "assistant", "content" => "Hi there"})

      loaded = Conversations.get_conversation!(scope, conv.id)
      assert loaded.id == conv.id
      assert loaded.person.id == person.id
      assert length(loaded.messages) == 2
      assert hd(loaded.messages).content == "Hello"
    end

    test "raises for other user's conversation", %{scope: scope} do
      %{scope: other_scope} = user_with_space_fixture()
      other_conv = conversation_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        Conversations.get_conversation!(scope, other_conv.id)
      end
    end
  end

  describe "create_conversation/2" do
    test "creates conversation with space and user from scope", %{scope: scope} do
      {:ok, conv} = Conversations.create_conversation(scope)

      assert conv.space_id == scope.space.id
      assert conv.user_id == scope.user.id
      assert conv.person_id == nil
      assert conv.title == nil
    end

    test "creates conversation with person", %{scope: scope, person: person} do
      {:ok, conv} = Conversations.create_conversation(scope, %{"person_id" => person.id})

      assert conv.person_id == person.id
    end

    test "creates conversation with title", %{scope: scope} do
      {:ok, conv} = Conversations.create_conversation(scope, %{"title" => "My chat"})

      assert conv.title == "My chat"
    end
  end

  describe "update_conversation/2" do
    test "updates title", %{scope: scope} do
      conv = conversation_fixture(scope)

      {:ok, updated} = Conversations.update_conversation(conv, %{"title" => "New title"})
      assert updated.title == "New title"
    end
  end

  describe "delete_conversation/2" do
    test "deletes own conversation", %{scope: scope} do
      conv = conversation_fixture(scope)

      assert {:ok, _} = Conversations.delete_conversation(scope, conv)
      assert_raise Ecto.NoResultsError, fn -> Conversations.get_conversation!(scope, conv.id) end
    end

    test "refuses to delete other user's conversation", %{scope: _scope} do
      %{scope: other_scope} = user_with_space_fixture()
      %{scope: attacker_scope} = user_with_space_fixture()
      conv = conversation_fixture(other_scope)

      assert {:error, :unauthorized} = Conversations.delete_conversation(attacker_scope, conv)
    end
  end

  describe "create_message/2" do
    test "creates a message in a conversation", %{scope: scope} do
      conv = conversation_fixture(scope)

      {:ok, msg} = Conversations.create_message(conv, %{"role" => "user", "content" => "Hello"})

      assert msg.conversation_id == conv.id
      assert msg.role == "user"
      assert msg.content == "Hello"
      assert msg.inserted_at != nil
    end

    test "validates role", %{scope: scope} do
      conv = conversation_fixture(scope)

      {:error, changeset} =
        Conversations.create_message(conv, %{"role" => "invalid", "content" => "Hello"})

      assert "is invalid" in errors_on(changeset).role
    end

    test "validates required fields", %{scope: scope} do
      conv = conversation_fixture(scope)

      {:error, changeset} = Conversations.create_message(conv, %{})
      assert errors_on(changeset).role != nil
      assert errors_on(changeset).content != nil
    end
  end

  describe "count_messages/1" do
    test "counts messages in a conversation", %{scope: scope} do
      conv = conversation_fixture(scope)
      assert Conversations.count_messages(conv) == 0

      message_fixture(conv)
      message_fixture(conv, %{"role" => "assistant", "content" => "Reply"})
      assert Conversations.count_messages(conv) == 2
    end
  end

  describe "count_messages_today/1" do
    test "counts user messages sent today in the space", %{scope: scope} do
      conv = conversation_fixture(scope)
      message_fixture(conv, %{"role" => "user", "content" => "Question 1"})
      message_fixture(conv, %{"role" => "user", "content" => "Question 2"})
      message_fixture(conv, %{"role" => "assistant", "content" => "Answer"})

      assert Conversations.count_messages_today(scope) == 2
    end

    test "counts across all users in the space", %{scope: scope, space: space} do
      conv1 = conversation_fixture(scope)
      message_fixture(conv1, %{"role" => "user", "content" => "Q1"})

      # Create another user in the same space
      other_user = Meddie.AccountsFixtures.user_fixture()

      Meddie.Repo.insert!(%Meddie.Spaces.Membership{
        user_id: other_user.id,
        space_id: space.id,
        role: "member"
      })

      other_scope =
        Meddie.Accounts.Scope.for_user(other_user) |> Meddie.Accounts.Scope.put_space(space)

      conv2 = conversation_fixture(other_scope)
      message_fixture(conv2, %{"role" => "user", "content" => "Q2"})

      assert Conversations.count_messages_today(scope) == 2
    end
  end

  describe "memory updates" do
    test "create and revert memory update", %{scope: scope, person: person} do
      conv = conversation_fixture(scope, %{"person_id" => person.id})
      msg = message_fixture(conv, %{"role" => "assistant", "content" => "I see"})

      {:ok, mu} =
        Conversations.create_memory_update(%{
          "message_id" => msg.id,
          "person_id" => person.id,
          "field" => "health_notes",
          "action" => "append",
          "text" => "Hypothyroidism",
          "previous_value" => nil
        })

      assert mu.field == "health_notes"
      assert mu.reverted == false

      {:ok, reverted} = Conversations.revert_memory_update(mu.id)
      assert reverted.reverted == true
    end
  end

  describe "get_or_create_telegram_conversation/2" do
    test "creates a new telegram conversation when none exists", %{scope: scope} do
      {:ok, conv} = Conversations.get_or_create_telegram_conversation(scope, nil)

      assert conv.source == "telegram"
      assert conv.user_id == scope.user.id
      assert conv.space_id == scope.space.id
    end

    test "returns existing telegram conversation", %{scope: scope} do
      {:ok, conv1} = Conversations.get_or_create_telegram_conversation(scope, nil)
      {:ok, conv2} = Conversations.get_or_create_telegram_conversation(scope, nil)

      assert conv1.id == conv2.id
    end

    test "does not return web conversations", %{scope: scope} do
      _web_conv = conversation_fixture(scope)

      {:ok, telegram_conv} = Conversations.get_or_create_telegram_conversation(scope, nil)

      assert telegram_conv.source == "telegram"
      # Should be a different conversation from the web one
      convs = Conversations.list_conversations(scope)
      assert length(convs) == 2
    end

    test "creates conversation with person_id when provided", %{scope: scope, person: person} do
      {:ok, conv} = Conversations.get_or_create_telegram_conversation(scope, person.id)

      assert conv.person_id == person.id
      assert conv.source == "telegram"
    end
  end

  describe "create_conversation/2 with source" do
    test "creates conversation with source telegram", %{scope: scope} do
      {:ok, conv} = Conversations.create_conversation(scope, %{"source" => "telegram"})

      assert conv.source == "telegram"
    end

    test "defaults source to web", %{scope: scope} do
      {:ok, conv} = Conversations.create_conversation(scope)

      assert conv.source == "web"
    end

    test "rejects invalid source", %{scope: scope} do
      {:error, changeset} = Conversations.create_conversation(scope, %{"source" => "invalid"})

      assert "is invalid" in errors_on(changeset).source
    end
  end
end
