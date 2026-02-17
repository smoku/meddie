defmodule Meddie.Conversations.Chat do
  @moduledoc """
  Shared chat logic used by both the web UI (AskMeddieLive.Show) and Telegram handler.
  Extracted to avoid duplication.
  """

  alias Meddie.Conversations
  alias Meddie.People
  alias Meddie.AI.Prompts

  use Gettext, backend: MeddieWeb.Gettext

  @max_ai_messages 20

  @doc """
  Parses metadata JSON block from the end of an AI response.
  Returns `{display_text, profile_updates_list, memory_saves_list}`.
  """
  def parse_response_metadata(text) do
    # Look for JSON block at end of response (with code fences)
    regex = ~r/```json\s*(\{[^`]*\})\s*```\s*\z/s

    case Regex.run(regex, text) do
      [full_match, json_str] ->
        display_text = String.trim(String.replace(text, full_match, ""))
        parse_json_block(display_text, json_str)

      nil ->
        # Try without code fences
        regex2 = ~r/(\{(?:"profile_updates"|"memory_saves").*?\})\s*\z/s

        case Regex.run(regex2, text) do
          [full_match, json_str] ->
            display_text = String.trim(String.replace(text, full_match, ""))
            parse_json_block(display_text, json_str)

          nil ->
            {text, [], []}
        end
    end
  end

  defp parse_json_block(display_text, json_str) do
    case Jason.decode(json_str) do
      {:ok, parsed} when is_map(parsed) ->
        updates = Map.get(parsed, "profile_updates", [])
        saves = Map.get(parsed, "memory_saves", [])
        updates = if is_list(updates), do: updates, else: []
        saves = if is_list(saves), do: Enum.filter(saves, &is_binary/1), else: []
        {display_text, updates, saves}

      _ ->
        {display_text, [], []}
    end
  end

  @doc """
  Applies profile updates to a person's profile fields.
  Returns a list of system messages that were created.
  """
  def apply_profile_updates(_scope, _conversation, _person, _assistant_msg, []), do: []

  def apply_profile_updates(scope, conversation, person, assistant_msg, updates) when not is_nil(person) do
    # Reload person to get fresh field values
    person = People.get_person!(scope, person.id)

    Enum.flat_map(updates, fn update ->
      field = update["field"]
      action = update["action"]
      text = update["text"]

      if field in ~w(health_notes supplements medications) and action in ~w(append remove) and text do
        previous_value = Map.get(person, String.to_existing_atom(field))

        new_value =
          case Meddie.AI.format_profile_field(previous_value, action, text) do
            {:ok, formatted} -> formatted
            {:error, _} -> apply_field_update(previous_value, action, text)
          end

        # Update person
        People.update_person(scope, person, %{field => new_value})

        # Create profile_update record
        Conversations.create_profile_update(%{
          "message_id" => assistant_msg.id,
          "person_id" => person.id,
          "field" => field,
          "action" => action,
          "text" => text,
          "previous_value" => previous_value
        })

        # Create system message
        action_text =
          case action do
            "append" -> gettext("Saved to %{field}: %{text}", field: display_field_name(field), text: text)
            "remove" -> gettext("Removed from %{field}: %{text}", field: display_field_name(field), text: text)
          end

        {:ok, sys_msg} =
          Conversations.create_message(conversation, %{
            "role" => "system",
            "content" => action_text
          })

        [sys_msg]
      else
        []
      end
    end)
  end

  def apply_profile_updates(_scope, _conversation, _person, _assistant_msg, _updates), do: []

  @doc """
  Saves semantic memory facts extracted by the AI during conversation.
  Skipped if no user is present (anonymous Telegram links).
  """
  def apply_memory_saves(_scope, []), do: :ok

  def apply_memory_saves(%{user: user, space: space}, saves) when not is_nil(user) do
    Enum.each(saves, fn fact_text ->
      Meddie.Memory.create_memory(user.id, space.id, %{
        content: fact_text,
        source: "chat"
      })
    end)
  end

  def apply_memory_saves(_scope, _saves), do: :ok

  @doc """
  Applies a field update (append or remove) to a person's field value.
  """
  def apply_field_update(nil, "append", text), do: text
  def apply_field_update("", "append", text), do: text
  def apply_field_update(current, "append", text), do: current <> "\n" <> text

  def apply_field_update(nil, "remove", _text), do: nil
  def apply_field_update("", "remove", _text), do: ""

  def apply_field_update(current, "remove", text) do
    current
    |> String.split("\n")
    |> Enum.reject(&String.contains?(&1, text))
    |> Enum.join("\n")
    |> String.trim()
  end

  @doc """
  Resolves which person a message is about using AI.
  Returns the resolved person or nil.
  """
  def resolve_person(message, people, scope) do
    case people do
      [] -> nil
      [single] -> single
      multiple -> resolve_person_via_ai(message, multiple, scope)
    end
  end

  @doc """
  Builds the system prompt for AI chat, including person context and memory facts.
  """
  def build_system_prompt(scope, person, memory_facts \\ []) do
    person_context =
      if person do
        Prompts.chat_context(scope, person)
      else
        nil
      end

    Prompts.chat_system_prompt(person_context, memory_facts)
  end

  @doc """
  Prepares messages for AI context (last N messages, user and assistant only).
  """
  def prepare_ai_messages(messages) do
    messages
    |> Enum.take(-@max_ai_messages)
    |> Enum.filter(&(&1.role in ["user", "assistant"]))
  end

  @doc """
  Splits a long text into chunks at paragraph boundaries, respecting max_length.
  """
  def split_message(text, max_length \\ 4096) do
    if String.length(text) <= max_length do
      [text]
    else
      do_split_message(text, max_length, [])
    end
  end

  defp do_split_message("", _max_length, acc), do: Enum.reverse(acc)

  defp do_split_message(text, max_length, acc) do
    if String.length(text) <= max_length do
      Enum.reverse([text | acc])
    else
      # Try to split at paragraph boundary
      chunk = String.slice(text, 0, max_length)

      split_pos =
        case :binary.match(String.reverse(chunk), "\n\n") do
          {pos, _} -> max_length - pos - 2
          :nomatch ->
            case :binary.match(String.reverse(chunk), "\n") do
              {pos, _} -> max_length - pos - 1
              :nomatch -> max_length
            end
        end

      {chunk, rest} = String.split_at(text, split_pos)
      rest = String.trim_leading(rest)
      do_split_message(rest, max_length, [chunk | acc])
    end
  end

  defp resolve_person_via_ai(message, people, scope) do
    people_context = Prompts.person_resolution_prompt(people, scope)

    case Meddie.AI.resolve_person(message, people_context) do
      {:ok, n} when is_integer(n) and n >= 1 and n <= length(people) ->
        Enum.at(people, n - 1)

      _ ->
        nil
    end
  end

  defp display_field_name("health_notes"), do: gettext("Health Notes")
  defp display_field_name("supplements"), do: gettext("Supplements")
  defp display_field_name("medications"), do: gettext("Medications")
  defp display_field_name(other), do: other
end
