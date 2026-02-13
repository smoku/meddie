defmodule Meddie.Memory.Embeddings do
  @moduledoc """
  Generates text embeddings using OpenAI text-embedding-3-small.
  Configurable via `:meddie, :embeddings_impl` for testing.
  """

  require Logger

  @api_url "https://api.openai.com/v1/embeddings"
  @model "text-embedding-3-small"
  @timeout 30_000

  @doc """
  Generate an embedding vector for a single text string.
  """
  def embed(text) do
    impl = Application.get_env(:meddie, :embeddings_impl, __MODULE__)

    if impl != __MODULE__ do
      impl.embed(text)
    else
      case do_embed_batch([text]) do
        {:ok, [embedding]} -> {:ok, embedding}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Generate embeddings for multiple texts in a single API call.
  """
  def embed_batch(texts) when is_list(texts) do
    impl = Application.get_env(:meddie, :embeddings_impl, __MODULE__)

    if impl != __MODULE__ do
      impl.embed_batch(texts)
    else
      do_embed_batch(texts)
    end
  end

  defp do_embed_batch(texts) do
    total_chars = texts |> Enum.map(&String.length/1) |> Enum.sum()
    Logger.debug("[AI] embed model=#{@model} texts=#{length(texts)} chars=#{total_chars}")

    body = %{"model" => @model, "input" => texts}

    case Req.post(@api_url,
           json: body,
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        embeddings =
          data
          |> Enum.sort_by(& &1["index"])
          |> Enum.map(& &1["embedding"])

        Logger.debug("[AI] embed result: #{length(embeddings)} embeddings")
        {:ok, embeddings}

      {:ok, %{status: status, body: body}} ->
        Logger.debug("[AI] embed error: status=#{status}")
        {:error, "OpenAI Embeddings API error: #{status} #{inspect(body)}"}

      {:error, reason} ->
        Logger.debug("[AI] embed error: #{inspect(reason)}")
        {:error, "OpenAI Embeddings request failed: #{inspect(reason)}"}
    end
  end

  defp api_key do
    Application.get_env(:meddie, :ai)[:openai_api_key] ||
      raise "OPENAI_API_KEY not configured"
  end
end
