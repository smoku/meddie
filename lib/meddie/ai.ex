defmodule Meddie.AI do
  @moduledoc """
  Facade for AI provider operations.
  Delegates to the configured parsing and chat providers.
  """

  def parse_document(images, person_context) do
    parsing_provider().parse_document(images, person_context)
  end

  def chat_stream(messages, system_prompt, callback) do
    chat_provider().chat_stream(messages, system_prompt, callback)
  end

  def chat(messages, system_prompt) do
    chat_provider().chat(messages, system_prompt)
  end

  def resolve_person(message, people_context) do
    chat_provider().resolve_person(message, people_context)
  end

  def generate_title(user_message, assistant_message) do
    chat_provider().generate_title(user_message, assistant_message)
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
end
