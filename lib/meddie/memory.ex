defmodule Meddie.Memory do
  @moduledoc """
  The Memory context. Manages semantic memory facts for users.
  Provides storage, retrieval, and hybrid search (vector + keyword).
  """

  import Ecto.Query
  alias Meddie.Repo
  alias Meddie.Memory.{Fact, Embeddings}

  @max_search_results 6
  @min_search_score 0.35
  @vector_weight 0.7
  @keyword_weight 0.3
  @dedup_threshold 0.92

  # -- Create --

  @doc """
  Creates a memory fact with embedding.
  Deduplicates by content hash and semantic similarity (cosine > 0.92).
  """
  def create_memory(user_id, space_id, attrs) do
    content = attrs[:content] || attrs["content"]
    content_hash = hash_content(content)

    existing =
      Repo.get_by(Fact,
        content_hash: content_hash,
        user_id: user_id,
        space_id: space_id
      )

    if existing do
      {:ok, :duplicate}
    else
      with {:ok, embedding} <- Embeddings.embed(content) do
        if semantic_duplicate?(user_id, space_id, embedding) do
          {:ok, :duplicate}
        else
          %Fact{user_id: user_id, space_id: space_id}
          |> Fact.changeset(
            Map.merge(normalize_attrs(attrs), %{
              content_hash: content_hash,
              embedding: embedding
            })
          )
          |> Repo.insert()
        end
      end
    end
  end

  # -- Search --

  @doc """
  Hybrid search: combines vector cosine similarity with full-text search.
  Returns top memories relevant to the query, sorted by combined score.
  """
  def search(user_id, space_id, query, opts \\ []) do
    max_results = Keyword.get(opts, :max_results, @max_search_results)
    min_score = Keyword.get(opts, :min_score, @min_search_score)

    with {:ok, query_embedding} <- Embeddings.embed(query) do
      candidates = max_results * 4

      vector_results = search_vector(user_id, space_id, query_embedding, candidates)
      keyword_results = search_keyword(user_id, space_id, query, candidates)

      merged =
        merge_hybrid(vector_results, keyword_results)
        |> Enum.filter(fn {_fact, score} -> score >= min_score end)
        |> Enum.take(max_results)
        |> Enum.map(fn {fact, _score} -> fact end)

      {:ok, merged}
    end
  end

  @doc """
  Convenience function for chat integration. Returns facts or empty list on error.
  """
  def search_for_prompt(scope, query_text) do
    if scope.user do
      case search(scope.user.id, scope.space.id, query_text) do
        {:ok, facts} -> facts
        {:error, _} -> []
      end
    else
      []
    end
  end

  # -- CRUD --

  def list_memories(user_id, space_id) do
    from(f in Fact,
      where: f.user_id == ^user_id and f.space_id == ^space_id and f.active == true,
      order_by: [desc: f.updated_at]
    )
    |> Repo.all()
  end

  def delete_memory(%Fact{} = fact) do
    fact |> Ecto.Changeset.change(active: false) |> Repo.update()
  end

  # -- Private: hashing --

  defp hash_content(content) do
    content
    |> String.trim()
    |> String.downcase()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # -- Private: deduplication --

  defp semantic_duplicate?(user_id, space_id, embedding) do
    max_distance = 1.0 - @dedup_threshold

    from(f in Fact,
      where: f.user_id == ^user_id and f.space_id == ^space_id and f.active == true,
      where: fragment("? <=> ? < ?", f.embedding, ^embedding, ^max_distance),
      limit: 1,
      select: f.id
    )
    |> Repo.one() != nil
  end

  # -- Private: vector search --

  defp search_vector(user_id, space_id, query_embedding, limit) do
    from(f in Fact,
      where: f.user_id == ^user_id and f.space_id == ^space_id and f.active == true,
      select: {f, fragment("1 - (? <=> ?)", f.embedding, ^query_embedding)},
      order_by: fragment("? <=> ?", f.embedding, ^query_embedding),
      limit: ^limit
    )
    |> Repo.all()
  end

  # -- Private: keyword search --

  defp search_keyword(user_id, space_id, query_text, limit) do
    tsquery = build_tsquery(query_text)

    if tsquery do
      from(f in Fact,
        where: f.user_id == ^user_id and f.space_id == ^space_id and f.active == true,
        where: fragment("content_tsv @@ to_tsquery('simple', ?)", ^tsquery),
        select:
          {f, fragment("ts_rank(content_tsv, to_tsquery('simple', ?))::float", ^tsquery)},
        order_by:
          [desc: fragment("ts_rank(content_tsv, to_tsquery('simple', ?))::float", ^tsquery)],
        limit: ^limit
      )
      |> Repo.all()
    else
      []
    end
  end

  defp build_tsquery(text) do
    tokens =
      text
      |> String.replace(~r/[^\w\s]/u, "")
      |> String.split(~r/\s+/, trim: true)
      |> Enum.filter(&(String.length(&1) > 1))

    if tokens == [] do
      nil
    else
      Enum.join(tokens, " & ")
    end
  end

  # -- Private: hybrid merge --

  defp merge_hybrid(vector_results, keyword_results) do
    max_keyword =
      keyword_results
      |> Enum.map(fn {_f, s} -> s end)
      |> Enum.max(fn -> 1.0 end)

    keyword_map =
      keyword_results
      |> Enum.map(fn {fact, score} ->
        {fact.id, {fact, score / max(max_keyword, 0.001)}}
      end)
      |> Map.new()

    vector_map =
      vector_results
      |> Enum.map(fn {fact, score} -> {fact.id, {fact, score}} end)
      |> Map.new()

    all_ids =
      MapSet.union(
        MapSet.new(Map.keys(vector_map)),
        MapSet.new(Map.keys(keyword_map))
      )

    all_ids
    |> Enum.map(fn id ->
      {vec_fact, vec_score} = Map.get(vector_map, id, {nil, 0.0})
      {kw_fact, kw_score} = Map.get(keyword_map, id, {nil, 0.0})
      fact = vec_fact || kw_fact
      combined = @vector_weight * vec_score + @keyword_weight * kw_score
      {fact, combined}
    end)
    |> Enum.sort_by(fn {_fact, score} -> score end, :desc)
  end

  # -- Private: attrs normalization --

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
