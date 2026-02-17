defmodule Meddie.AI.Provider do
  @moduledoc """
  Behaviour for AI providers (OpenAI, Anthropic).
  """

  @doc """
  Parse a medical document from one or more page images.
  Each image is a `{binary_data, content_type}` tuple.
  Returns structured parsing results.
  """
  @callback parse_document(
              images :: list({binary(), String.t()}),
              person_context :: String.t()
            ) :: {:ok, map()} | {:error, String.t()}

  @doc """
  Stream a chat response given messages and context.
  The callback receives chunks as they arrive.
  """
  @callback chat_stream(
              messages :: list(map()),
              system_prompt :: String.t(),
              callback :: function()
            ) :: :ok | {:error, String.t()}

  @doc """
  Resolve which person a message is about, given a list of people in the space.
  Returns the person number (1-indexed) from the list, or nil if unclear.
  Uses a fast, cheap model. Non-streaming.
  """
  @callback resolve_person(message :: String.t(), people_context :: String.t()) ::
              {:ok, integer() | nil} | {:error, String.t()}

  @doc """
  Non-streaming chat response given messages and context.
  Returns the full response text. Used by Telegram integration.
  """
  @callback chat(
              messages :: list(map()),
              system_prompt :: String.t()
            ) :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Generate a short conversation title from the first user message and assistant response.
  Uses a fast, cheap model. Non-streaming.
  """
  @callback generate_title(user_message :: String.t(), assistant_message :: String.t()) ::
              {:ok, String.t()} | {:error, String.t()}

  @doc """
  Format a profile field update using a fast model.
  Merges the update into the existing field content producing clean markdown.
  Uses a fast, cheap model. Non-streaming.
  """
  @callback format_profile_field(
              current_value :: String.t() | nil,
              action :: String.t(),
              text :: String.t()
            ) :: {:ok, String.t()} | {:error, String.t()}
end
