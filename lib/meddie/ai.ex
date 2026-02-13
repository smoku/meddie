defmodule Meddie.AI do
  @moduledoc """
  Facade for AI provider operations.
  Delegates to the configured parsing and chat providers.
  Logs all communication at debug level for development visibility.
  """

  require Logger

  def parse_document(images, person_context) do
    provider = parsing_provider()
    Logger.debug("[AI] parse_document via #{provider_name(provider)} images=#{length(images)}")

    result = provider.parse_document(images, person_context)

    case result do
      {:ok, parsed} -> Logger.debug("[AI] parse_document result: #{inspect(parsed, limit: 2000)}")
      {:error, err} -> Logger.debug("[AI] parse_document error: #{inspect(err)}")
    end

    result
  end

  def chat_stream(messages, system_prompt, callback) do
    provider = chat_provider()
    Logger.debug("[AI] chat_stream via #{provider_name(provider)}")
    Logger.debug("[AI] system_prompt:\n#{system_prompt}")
    Logger.debug("[AI] messages (#{length(messages)}):\n#{format_messages(messages)}")

    Process.put(:ai_stream_acc, "")

    wrapped_callback = fn %{content: text} = chunk ->
      Process.put(:ai_stream_acc, (Process.get(:ai_stream_acc) || "") <> text)
      callback.(chunk)
    end

    result = provider.chat_stream(messages, system_prompt, wrapped_callback)
    full_response = Process.delete(:ai_stream_acc)
    Logger.debug("[AI] chat_stream response:\n#{full_response}")
    result
  end

  def chat(messages, system_prompt) do
    provider = chat_provider()
    Logger.debug("[AI] chat via #{provider_name(provider)}")
    Logger.debug("[AI] system_prompt:\n#{system_prompt}")
    Logger.debug("[AI] messages (#{length(messages)}):\n#{format_messages(messages)}")

    result = provider.chat(messages, system_prompt)

    case result do
      {:ok, text} -> Logger.debug("[AI] chat response:\n#{text}")
      {:error, err} -> Logger.debug("[AI] chat error: #{inspect(err)}")
    end

    result
  end

  def resolve_person(message, people_context) do
    provider = chat_provider()

    Logger.debug(
      "[AI] resolve_person via #{provider_name(provider)}\n  message: #{message}\n  people: #{people_context}"
    )

    result = provider.resolve_person(message, people_context)
    Logger.debug("[AI] resolve_person result: #{inspect(result)}")
    result
  end

  def generate_title(user_message, assistant_message) do
    provider = chat_provider()
    Logger.debug("[AI] generate_title via #{provider_name(provider)}")

    result = provider.generate_title(user_message, assistant_message)
    Logger.debug("[AI] generate_title result: #{inspect(result)}")
    result
  end

  defp parsing_provider do
    config()[:parsing_provider] || raise "No AI parsing provider configured"
  end

  defp chat_provider do
    config()[:chat_provider] || raise "No AI chat provider configured"
  end

  defp config do
    Application.get_env(:meddie, :ai, [])
  end

  defp provider_name(provider), do: provider |> Module.split() |> List.last()

  defp format_messages(messages) do
    Enum.map_join(messages, "\n---\n", fn msg ->
      "[#{msg.role}] #{String.slice(msg.content, 0..500)}"
    end)
  end
end
