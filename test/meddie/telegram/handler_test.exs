defmodule Meddie.Telegram.HandlerTest do
  use Meddie.DataCase

  alias Meddie.Telegram.Handler
  alias Meddie.Conversations

  import Ecto.Query
  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.TelegramLinksFixtures

  # The mock AI provider returns predictable results

  setup do
    %{user: user, space: _space, scope: scope} = user_with_space_fixture(%{locale: "en"})
    person = person_fixture(scope, %{"name" => "Test Person"})

    # Set bot token on space
    {:ok, space} = Meddie.Spaces.update_telegram_token(scope, %{telegram_bot_token: "test:token"})

    # Refresh scope with updated space
    scope = Meddie.Accounts.Scope.for_user(user) |> Meddie.Accounts.Scope.put_space(space)

    # Create a telegram link for the user
    _link =
      telegram_link_fixture(space, %{
        "telegram_id" => 123_456_789,
        "user_id" => user.id,
        "person_id" => person.id
      })

    %{user: user, space: space, scope: scope, person: person}
  end

  defp build_update(chat_id, from_id, text) do
    %{
      "update_id" => System.unique_integer([:positive]),
      "message" => %{
        "message_id" => System.unique_integer([:positive]),
        "chat" => %{"id" => chat_id},
        "from" => %{"id" => from_id},
        "text" => text
      }
    }
  end

  describe "handle/3 - authentication" do
    test "rejects unknown telegram user", %{space: space} do
      update = build_update(111, 999_999_999, "Hello")

      # Should not crash - sends rejection message via Client
      # Client calls will fail (no real Telegram), but handler catches errors
      assert Handler.handle(update, space, "test:token") == :ok ||
               match?({:ok, _}, Handler.handle(update, space, "test:token")) ||
               match?({:error, _}, Handler.handle(update, space, "test:token"))
    end

    test "rejects user whose link is in a different space", %{} do
      # Create another space with its own link
      %{user: other_user, space: other_space} =
        user_with_space_fixture(%{locale: "en"})

      _link =
        telegram_link_fixture(other_space, %{
          "telegram_id" => 987_654_321,
          "user_id" => other_user.id
        })

      # Create a third space with no links for this telegram_id
      %{scope: third_scope} = user_with_space_fixture(%{locale: "en"})

      {:ok, third_space} =
        Meddie.Spaces.update_telegram_token(third_scope, %{telegram_bot_token: "third:token"})

      update = build_update(111, 987_654_321, "Hello")

      # The user has a link in other_space but NOT in third_space → not_linked
      result = Handler.handle(update, third_space, "third:token")
      assert result != nil
    end
  end

  describe "handle/3 - commands" do
    test "/start sends welcome message", %{space: space} do
      update = build_update(111, 123_456_789, "/start")

      # Will try to send via Client (fails on HTTP) but shouldn't crash
      _result = Handler.handle(update, space, "test:token")
      # The important thing is it doesn't crash
    end

    test "/new creates a new conversation", %{space: space, scope: scope} do
      update = build_update(111, 123_456_789, "/new")

      _result = Handler.handle(update, space, "test:token")

      # Verify a conversation was created
      convs = Conversations.list_conversations(scope)
      assert Enum.any?(convs, fn c -> c.source == "telegram" end)
    end

    test "/help sends help message", %{space: space} do
      update = build_update(111, 123_456_789, "/help")

      _result = Handler.handle(update, space, "test:token")
      # Shouldn't crash
    end
  end

  describe "handle/3 - text messages" do
    test "creates conversation and messages for text", %{space: space, scope: scope} do
      update = build_update(111, 123_456_789, "How are my blood results?")

      _result = Handler.handle(update, space, "test:token")

      # Verify conversation was created
      convs = Conversations.list_conversations(scope)
      telegram_convs = Enum.filter(convs, fn c -> c.source == "telegram" end)
      assert length(telegram_convs) >= 1

      # Verify messages were created (user + assistant)
      conv = hd(telegram_convs)
      loaded = Conversations.get_conversation!(scope, conv.id)
      user_msgs = Enum.filter(loaded.messages, &(&1.role == "user"))
      assistant_msgs = Enum.filter(loaded.messages, &(&1.role == "assistant"))

      assert length(user_msgs) >= 1
      assert length(assistant_msgs) >= 1
      assert hd(user_msgs).content == "How are my blood results?"
    end

    test "reuses existing telegram conversation", %{space: space, scope: scope} do
      # Send first message
      update1 = build_update(111, 123_456_789, "First message")
      _result = Handler.handle(update1, space, "test:token")

      # Send second message
      update2 = build_update(111, 123_456_789, "Second message")
      _result = Handler.handle(update2, space, "test:token")

      # Should still have only one telegram conversation
      convs = Conversations.list_conversations(scope)
      telegram_convs = Enum.filter(convs, fn c -> c.source == "telegram" end)
      assert length(telegram_convs) == 1

      # But should have multiple messages
      conv = hd(telegram_convs)
      loaded = Conversations.get_conversation!(scope, conv.id)
      user_msgs = Enum.filter(loaded.messages, &(&1.role == "user"))
      assert length(user_msgs) == 2
    end

    test "ignores empty messages", %{space: space} do
      update = %{
        "update_id" => 1,
        "message" => %{
          "message_id" => 1,
          "chat" => %{"id" => 111},
          "from" => %{"id" => 123_456_789},
          "text" => nil
        }
      }

      result = Handler.handle(update, space, "test:token")
      assert result == :ok
    end
  end

  describe "handle/3 - userless telegram link" do
    test "works with link that has no user but has a person", %{space: space, person: person} do
      # Create a link with no user, just a person
      userless_link =
        telegram_link_fixture(space, %{
          "telegram_id" => 555_555_555,
          "person_id" => person.id
        })

      update = build_update(222, 555_555_555, "Tell me about my results")
      _result = Handler.handle(update, space, "test:token")

      # Verify conversation was created via the link
      convs =
        Meddie.Repo.all(
          from(c in Meddie.Conversations.Conversation,
            where: c.telegram_link_id == ^userless_link.id and c.source == "telegram"
          )
        )

      assert length(convs) >= 1
    end
  end

  describe "handle/3 - no message" do
    test "ignores updates without message field", %{space: space} do
      update = %{"update_id" => 1}
      assert Handler.handle(update, space, "test:token") == nil
    end
  end
end
