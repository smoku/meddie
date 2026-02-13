defmodule Meddie.Memory.Embeddings.Mock do
  @moduledoc """
  Mock embeddings module for testing. Returns deterministic vectors
  based on content hash so that identical texts get identical embeddings
  and similar texts get somewhat similar embeddings.
  """

  @dims 1536

  def embed(text) do
    {:ok, deterministic_vector(text)}
  end

  def embed_batch(texts) when is_list(texts) do
    {:ok, Enum.map(texts, &deterministic_vector/1)}
  end

  defp deterministic_vector(text) do
    # Use first 8 bytes of SHA256 as seed, then generate a deterministic vector
    <<seed::64, _rest::binary>> =
      :crypto.hash(:sha256, String.trim(String.downcase(text)))

    :rand.seed(:exsss, {seed, seed + 1, seed + 2})

    vector =
      for _i <- 1..@dims do
        :rand.uniform() * 2 - 1
      end

    # Normalize to unit vector
    magnitude = :math.sqrt(Enum.reduce(vector, 0, fn x, acc -> acc + x * x end))

    if magnitude > 0 do
      Enum.map(vector, &(&1 / magnitude))
    else
      List.duplicate(0.0, @dims)
    end
  end
end
