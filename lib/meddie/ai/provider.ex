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
end
