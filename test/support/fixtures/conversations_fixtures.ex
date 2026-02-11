defmodule Meddie.ConversationsFixtures do
  @moduledoc """
  Test helpers for creating Conversations and Messages.
  """

  alias Meddie.Conversations

  def conversation_fixture(scope, attrs \\ %{}) do
    {:ok, conversation} = Conversations.create_conversation(scope, attrs)
    conversation
  end

  def message_fixture(conversation, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "role" => "user",
        "content" => "Test message #{System.unique_integer([:positive])}"
      })

    {:ok, message} = Conversations.create_message(conversation, attrs)
    message
  end
end
