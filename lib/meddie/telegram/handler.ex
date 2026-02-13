defmodule Meddie.Telegram.Handler do
  @moduledoc """
  Processes incoming Telegram updates. Routes commands and messages,
  enforces access control, and delegates to AI chat.
  """

  require Logger

  alias Meddie.Accounts
  alias Meddie.Accounts.Scope
  alias Meddie.Conversations
  alias Meddie.Conversations.Chat
  alias Meddie.People
  alias Meddie.Telegram.{Client, Links}

  @daily_message_limit 200

  @doc """
  Handles a single Telegram update for a given space.
  """
  def handle(update, space, token) do
    message = update["message"]

    if message do
      chat_id = message["chat"]["id"]
      telegram_user_id = message["from"]["id"]

      case authenticate(telegram_user_id, space) do
        {:ok, scope, link} ->
          handle_message(message, scope, link, space, token, chat_id)

        {:error, :not_linked} ->
          Client.send_message(token, chat_id,
            "I don't recognize your Telegram account. " <>
              "Please ask your Space admin to link your Telegram ID in Settings.\n\n" <>
              "Your Telegram ID: `#{telegram_user_id}`"
          )
      end
    end
  end

  defp authenticate(telegram_user_id, space) do
    case Links.get_link(telegram_user_id, space.id) do
      nil ->
        {:error, :not_linked}

      %{user_id: user_id} = link when not is_nil(user_id) ->
        user = Accounts.get_user!(user_id)
        scope = Scope.for_user(user) |> Scope.put_space(space)
        {:ok, scope, link}

      link ->
        scope = Scope.for_space(space)
        {:ok, scope, link}
    end
  end

  defp handle_message(message, scope, link, space, token, chat_id) do
    text = message["text"]

    cond do
      text && String.starts_with?(text, "/start") ->
        handle_start(space, token, chat_id)

      text && String.starts_with?(text, "/new") ->
        handle_new(space, link, token, chat_id)

      text && String.starts_with?(text, "/help") ->
        handle_help(token, chat_id)

      text && String.length(String.trim(text)) > 0 ->
        handle_text_message(scope, link, space, token, chat_id, String.trim(text))

      true ->
        # Ignore empty or unsupported message types (photos, documents deferred)
        :ok
    end
  end

  defp handle_start(space, token, chat_id) do
    Client.send_message(token, chat_id,
      "Welcome to Meddie! You're connected to *#{space.name}*.\n\n" <>
        "Send me a message to ask about health data, or use:\n" <>
        "/new — Start a new conversation\n" <>
        "/help — Show available commands"
    )
  end

  defp handle_new(space, link, token, chat_id) do
    {:ok, _conversation} =
      Conversations.create_telegram_conversation(space, link, link.person_id)

    Client.send_message(token, chat_id,
      "Started a new conversation. What would you like to know?"
    )
  end

  defp handle_help(token, chat_id) do
    Client.send_message(token, chat_id,
      "*Available commands:*\n\n" <>
        "/start — Welcome message\n" <>
        "/new — Start a new conversation\n" <>
        "/help — Show this help\n\n" <>
        "Send any text message to chat with Meddie about your health data."
    )
  end

  defp handle_text_message(scope, link, space, token, chat_id, text) do
    # Check rate limit
    if Conversations.count_messages_today(scope) >= @daily_message_limit do
      Client.send_message(token, chat_id,
        "You've reached the daily message limit. Try again tomorrow."
      )
    else
      do_chat(scope, link, space, token, chat_id, text)
    end
  end

  defp do_chat(scope, link, space, token, chat_id, text) do
    # Get or create telegram conversation
    people = People.list_people(scope)
    {:ok, conversation} = Conversations.get_or_create_telegram_link_conversation(space, link, link.person_id)

    # Resolve person: use link.person_id if set, otherwise AI resolution
    {conversation, person} =
      if link.person_id do
        person = Enum.find(people, &(&1.id == link.person_id))
        {conversation, person}
      else
        maybe_resolve_person(conversation, text, people, scope)
      end

    # Save user message
    {:ok, _user_msg} = Conversations.create_message(conversation, %{"role" => "user", "content" => text})

    # Send typing indicator
    Client.send_chat_action(token, chat_id)

    # Build AI context with memory
    memory_facts = Meddie.Memory.search_for_prompt(scope, text)
    system_prompt = Chat.build_system_prompt(scope, person, memory_facts)
    messages = Conversations.list_messages(conversation)
    ai_messages = Chat.prepare_ai_messages(messages)

    # Carry forward context from previous conversation for continuity
    previous_messages =
      Conversations.get_previous_conversation_messages(space, link)
      |> Enum.map(fn msg -> %{role: msg.role, content: msg.content} end)

    ai_messages = previous_messages ++ ai_messages

    # Call AI (non-streaming)
    case Meddie.AI.chat(ai_messages, system_prompt) do
      {:ok, response_text} ->
        # Parse profile updates + memory saves
        {display_text, profile_updates_data, memory_saves_data} = Chat.parse_response_metadata(response_text)

        # Save assistant message
        {:ok, assistant_msg} = Conversations.create_message(conversation, %{"role" => "assistant", "content" => display_text})

        # Apply profile updates (person profile fields)
        system_messages = Chat.apply_profile_updates(scope, conversation, person, assistant_msg, profile_updates_data)

        # Apply memory saves (semantic facts)
        Chat.apply_memory_saves(scope, memory_saves_data)

        # Send response (split if needed)
        chunks = Chat.split_message(display_text)
        Enum.each(chunks, fn chunk ->
          Client.send_message(token, chat_id, chunk)
        end)

        # Send memory update notifications
        Enum.each(system_messages, fn sys_msg ->
          Client.send_message(token, chat_id, "_#{sys_msg.content}_")
        end)

        # Update conversation timestamp
        Conversations.update_conversation(conversation, %{})

        # Generate title async
        maybe_generate_title(conversation, messages ++ [assistant_msg])

      {:error, reason} ->
        Logger.error("Telegram AI chat error: #{inspect(reason)}")
        Client.send_message(token, chat_id, "Something went wrong. Please try again.")
    end
  end

  defp maybe_resolve_person(conversation, text, people, scope) do
    if conversation.person_id do
      person = Enum.find(people, &(&1.id == conversation.person_id))
      {conversation, person}
    else
      resolved = Chat.resolve_person(text, people, scope)

      if resolved do
        {:ok, conversation} = Conversations.update_conversation(conversation, %{"person_id" => resolved.id})
        {conversation, resolved}
      else
        {conversation, nil}
      end
    end
  end

  defp maybe_generate_title(conversation, messages) do
    if is_nil(conversation.title) do
      user_msgs = Enum.filter(messages, &(&1.role == "user"))
      assistant_msgs = Enum.filter(messages, &(&1.role == "assistant"))

      if length(user_msgs) >= 1 and length(assistant_msgs) >= 1 do
        first_user = hd(user_msgs).content
        first_assistant = hd(assistant_msgs).content

        Task.start(fn ->
          case Meddie.AI.generate_title(first_user, first_assistant) do
            {:ok, title} ->
              Conversations.update_conversation(conversation, %{"title" => title})

            _ ->
              :ok
          end
        end)
      end
    end
  end
end
