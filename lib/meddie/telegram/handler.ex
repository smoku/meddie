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
  alias Meddie.Documents
  alias Meddie.People
  alias Meddie.Telegram.{Client, Links}

  @daily_message_limit 200

  @doc """
  Handles a single Telegram update for a given space.
  """
  def handle(update, space, token) do
    cond do
      update["message"] ->
        message = update["message"]
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

      update["callback_query"] ->
        handle_callback_query(update["callback_query"], space, token)

      true ->
        :ok
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
    photo = message["photo"]
    document = message["document"]

    cond do
      text && String.starts_with?(text, "/start") ->
        handle_start(space, token, chat_id)

      text && String.starts_with?(text, "/new") ->
        handle_new(space, link, token, chat_id)

      text && String.starts_with?(text, "/help") ->
        handle_help(token, chat_id)

      photo ->
        handle_photo_message(scope, link, space, token, chat_id, message)

      document && supported_document?(document) ->
        handle_document_message(scope, link, space, token, chat_id, message)

      text && String.length(String.trim(text)) > 0 ->
        handle_text_message(scope, link, space, token, chat_id, String.trim(text))

      true ->
        :ok
    end
  end

  defp supported_document?(document) do
    document["mime_type"] in ["application/pdf", "image/jpeg", "image/png"]
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
    ai_messages = Chat.prepare_ai_messages_with_images(messages)

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

  # -- File message handling --

  defp handle_photo_message(scope, link, space, token, chat_id, message) do
    # Telegram sends multiple sizes — pick the largest (last)
    photo = List.last(message["photo"])
    file_id = photo["file_id"]
    caption = message["caption"] || ""

    handle_file_message(scope, link, space, token, chat_id, file_id, "image/jpeg", "photo.jpg", caption)
  end

  defp handle_document_message(scope, link, space, token, chat_id, message) do
    doc = message["document"]
    file_id = doc["file_id"]
    mime_type = doc["mime_type"]
    filename = doc["file_name"] || "document"
    caption = message["caption"] || ""

    handle_file_message(scope, link, space, token, chat_id, file_id, mime_type, filename, caption)
  end

  defp handle_file_message(scope, link, space, token, chat_id, file_id, mime_type, filename, caption) do
    if Conversations.count_messages_today(scope) >= @daily_message_limit do
      Client.send_message(token, chat_id, "You've reached the daily message limit. Try again tomorrow.")
    else
      Client.send_chat_action(token, chat_id)

      with {:ok, file_info} <- Client.get_file(token, file_id),
           {:ok, file_data} <- Client.download_file(token, file_info["file_path"]) do
        do_file_chat(scope, link, space, token, chat_id, file_data, mime_type, filename, caption)
      else
        {:error, reason} ->
          Logger.error("Telegram file download error: #{inspect(reason)}")
          Client.send_message(token, chat_id, "Could not download the file. Please try again.")
      end
    end
  end

  defp do_file_chat(scope, link, space, token, chat_id, file_data, mime_type, filename, caption) do
    people = People.list_people(scope)
    {:ok, conversation} = Conversations.get_or_create_telegram_link_conversation(space, link, link.person_id)

    # Resolve person
    {conversation, person} =
      if link.person_id do
        person = Enum.find(people, &(&1.id == link.person_id))
        {conversation, person}
      else
        msg_text = if caption != "", do: caption, else: filename
        maybe_resolve_person(conversation, msg_text, people, scope)
      end

    # Store file
    attachment_id = Ecto.UUID.generate()
    storage_path = "chat_attachments/#{space.id}/#{conversation.id}/#{attachment_id}/#{filename}"
    :ok = Meddie.Storage.put(storage_path, file_data, mime_type)

    # Save user message with attachment
    msg_content = if caption != "", do: caption, else: filename

    {:ok, user_msg} =
      Conversations.create_message(conversation, %{
        "role" => "user",
        "content" => msg_content,
        "attachment_path" => storage_path,
        "attachment_type" => mime_type,
        "attachment_name" => filename
      })

    # Send typing indicator
    Client.send_chat_action(token, chat_id)

    # Build AI context
    memory_facts = Meddie.Memory.search_for_prompt(scope, msg_content)
    system_prompt = Chat.build_system_prompt(scope, person, memory_facts)
    messages = Conversations.list_messages(conversation)
    ai_messages = Chat.prepare_ai_messages_with_images(messages)

    # Carry forward context from previous conversation
    previous_messages =
      Conversations.get_previous_conversation_messages(space, link)
      |> Enum.map(fn msg -> %{role: msg.role, content: msg.content} end)

    ai_messages = previous_messages ++ ai_messages

    # Call AI (non-streaming)
    case Meddie.AI.chat(ai_messages, system_prompt) do
      {:ok, response_text} ->
        {display_text, profile_updates_data, memory_saves_data} = Chat.parse_response_metadata(response_text)

        {:ok, assistant_msg} =
          Conversations.create_message(conversation, %{"role" => "assistant", "content" => display_text})

        system_messages = Chat.apply_profile_updates(scope, conversation, person, assistant_msg, profile_updates_data)
        Chat.apply_memory_saves(scope, memory_saves_data)

        # Send response
        chunks = Chat.split_message(display_text)
        Enum.each(chunks, fn chunk -> Client.send_message(token, chat_id, chunk) end)

        Enum.each(system_messages, fn sys_msg ->
          Client.send_message(token, chat_id, "_#{sys_msg.content}_")
        end)

        # Offer to save as document (only if person is known)
        if person do
          keyboard = %{
            "inline_keyboard" => [
              [
                %{"text" => "Save to documents", "callback_data" => "save_doc:#{user_msg.id}"},
                %{"text" => "No", "callback_data" => "skip_doc"}
              ]
            ]
          }

          Client.send_message(
            token,
            chat_id,
            "Save this file to #{person.name}'s documents?",
            reply_markup: keyboard
          )
        end

        Conversations.update_conversation(conversation, %{})
        maybe_generate_title(conversation, messages ++ [assistant_msg])

      {:error, reason} ->
        Logger.error("Telegram AI file error: #{inspect(reason)}")
        Client.send_message(token, chat_id, "Something went wrong analyzing your file. Please try again.")
    end
  end

  # -- Callback query handling --

  defp handle_callback_query(callback_query, space, token) do
    data = callback_query["data"]
    chat_id = callback_query["message"]["chat"]["id"]
    message_id = callback_query["message"]["message_id"]
    telegram_user_id = callback_query["from"]["id"]

    Client.answer_callback_query(token, callback_query["id"])

    case authenticate(telegram_user_id, space) do
      {:ok, scope, link} ->
        cond do
          String.starts_with?(data || "", "save_doc:") ->
            msg_id = String.replace_prefix(data, "save_doc:", "")
            handle_save_document_callback(scope, link, space, token, chat_id, message_id, msg_id)

          data == "skip_doc" ->
            Client.edit_message_text(token, chat_id, message_id, "File not saved.")

          true ->
            :ok
        end

      {:error, _} ->
        :ok
    end
  end

  defp handle_save_document_callback(scope, link, space, token, chat_id, message_id, msg_id) do
    case Conversations.get_message(msg_id) do
      nil ->
        Client.edit_message_text(token, chat_id, message_id, "File no longer available.")

      msg ->
        if msg.attachment_path do
          # Determine person from link or conversation
          person_id = link.person_id || msg.conversation_id && get_conversation_person_id(msg.conversation_id)

          if person_id do
            case save_telegram_attachment(scope, space, person_id, msg) do
              {:ok, _} ->
                Client.edit_message_text(token, chat_id, message_id, "Document saved and queued for parsing.")

              {:error, :duplicate} ->
                Client.edit_message_text(token, chat_id, message_id, "This document was already saved.")

              {:error, _} ->
                Client.edit_message_text(token, chat_id, message_id, "Could not save document.")
            end
          else
            Client.edit_message_text(token, chat_id, message_id, "No person associated. File not saved.")
          end
        else
          Client.edit_message_text(token, chat_id, message_id, "File no longer available.")
        end
    end
  end

  defp get_conversation_person_id(conversation_id) do
    case Conversations.get_conversation_by_id(conversation_id) do
      nil -> nil
      conv -> conv.person_id
    end
  end

  defp save_telegram_attachment(scope, space, person_id, msg) do
    case Meddie.Storage.get(msg.attachment_path) do
      {:ok, file_data} ->
        content_hash = :crypto.hash(:sha256, file_data) |> Base.encode16(case: :lower)

        if Documents.document_exists_by_hash?(scope, person_id, content_hash) do
          {:error, :duplicate}
        else
          document_id = Ecto.UUID.generate()
          filename = msg.attachment_name
          doc_storage_path = "documents/#{space.id}/#{person_id}/#{document_id}/#{filename}"

          :ok = Meddie.Storage.put(doc_storage_path, file_data, msg.attachment_type)

          attrs = %{
            "filename" => filename,
            "content_type" => msg.attachment_type,
            "file_size" => byte_size(file_data),
            "storage_path" => doc_storage_path,
            "content_hash" => content_hash
          }

          case Documents.create_document(scope, person_id, attrs) do
            {:ok, document} ->
              %{document_id: document.id} |> Meddie.Workers.ParseDocument.new() |> Oban.insert()
              {:ok, document}

            error ->
              error
          end
        end

      error ->
        error
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
