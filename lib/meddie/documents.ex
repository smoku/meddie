defmodule Meddie.Documents do
  @moduledoc """
  The Documents context. Manages medical documents and biomarkers within a Space.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts.Scope
  alias Meddie.Documents.{Document, Biomarker}

  @topic_prefix "documents:person:"

  def subscribe_person_documents(person_id) do
    Phoenix.PubSub.subscribe(Meddie.PubSub, @topic_prefix <> person_id)
  end

  def broadcast_document_update(%Document{} = document) do
    Phoenix.PubSub.broadcast(
      Meddie.PubSub,
      @topic_prefix <> document.person_id,
      {:document_updated, document}
    )
  end

  @doc """
  Returns documents for a person in the given scope, in reverse chronological order.
  Supports `:limit` and `:offset` options for pagination.
  """
  def list_documents(%Scope{space: space}, person_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    from(d in Document,
      where: d.space_id == ^space.id and d.person_id == ^person_id,
      order_by: [desc: d.inserted_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:biomarkers]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single document scoped to the given space, with biomarkers preloaded.
  Raises `Ecto.NoResultsError` if not found.
  """
  def get_document!(%Scope{space: space}, id) do
    from(d in Document,
      where: d.id == ^id and d.space_id == ^space.id,
      preload: [biomarkers: ^from(b in Biomarker, order_by: [asc: b.category, asc: b.name])]
    )
    |> Repo.one!()
  end

  @doc """
  Gets a document by ID without scope (for Oban worker). Preloads person.
  """
  def get_document!(id) do
    Repo.get!(Document, id) |> Repo.preload(:person)
  end

  @doc """
  Creates a document for a person in the given scope's space.
  """
  def create_document(%Scope{space: space}, person_id, attrs) do
    %Document{space_id: space.id, person_id: person_id}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a document (status transitions, parsing results, etc.).
  """
  def update_document(%Document{} = document, attrs) do
    document
    |> Document.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a document.
  """
  def delete_document(%Scope{}, %Document{} = document) do
    Repo.delete(document)
  end

  @doc """
  Bulk inserts biomarkers for a document.
  """
  def create_biomarkers(%Document{} = document, biomarkers_data) when is_list(biomarkers_data) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(biomarkers_data, fn data ->
        data
        |> Map.put(:document_id, document.id)
        |> Map.put(:space_id, document.space_id)
        |> Map.put(:person_id, document.person_id)
        |> Map.put(:id, Ecto.UUID.generate())
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)
      end)

    Repo.insert_all(Biomarker, entries)
  end

  @doc """
  Checks if a document with the given content hash already exists for a person.
  """
  def document_exists_by_hash?(%Scope{space: space}, person_id, content_hash) do
    Repo.exists?(
      from(d in Document,
        where:
          d.space_id == ^space.id and d.person_id == ^person_id and
            d.content_hash == ^content_hash
      )
    )
  end

  @doc """
  Returns the count of documents for a person in the given scope.
  """
  def count_documents(%Scope{space: space}, person_id) do
    from(d in Document,
      where: d.space_id == ^space.id and d.person_id == ^person_id,
      select: count(d.id)
    )
    |> Repo.one()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking document changes.
  """
  def change_document(%Document{} = document, attrs \\ %{}) do
    Document.changeset(document, attrs)
  end

  # -- Biomarker queries --

  @doc """
  Returns all biomarkers for a person from parsed lab_results documents,
  ordered by category, name, and document date. Documents are preloaded.
  """
  def list_person_biomarkers(%Scope{space: space}, person_id) do
    from(b in Biomarker,
      join: d in assoc(b, :document),
      where: b.space_id == ^space.id and b.person_id == ^person_id,
      where: d.status == "parsed" and d.document_type == "lab_results",
      order_by: [asc: b.category, asc: b.name, asc: d.document_date, asc: d.inserted_at],
      preload: [document: d]
    )
    |> Repo.all()
  end

  @doc """
  Returns biomarker counts grouped by status for a person.
  Returns a map like `%{"normal" => 5, "high" => 2}`.

  Counts unique biomarker names (latest per name) rather than total rows.
  """
  def count_person_biomarkers_by_status(%Scope{space: space}, person_id) do
    from(b in Biomarker,
      join: d in assoc(b, :document),
      where: b.space_id == ^space.id and b.person_id == ^person_id,
      where: d.status == "parsed" and d.document_type == "lab_results",
      group_by: b.status,
      select: {b.status, count(b.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns biomarker history for given names and person, grouped by name.
  Only includes entries with non-nil numeric_value (for sparklines/charts).

  Returns `%{"Hemoglobina" => [%{numeric_value: 14.5, status: "normal", ...}]}`.
  """
  def list_biomarker_history(%Scope{space: space}, person_id, biomarker_names)
      when is_list(biomarker_names) do
    from(b in Biomarker,
      join: d in assoc(b, :document),
      where: b.space_id == ^space.id and b.person_id == ^person_id,
      where: b.name in ^biomarker_names,
      where: d.status == "parsed" and d.document_type == "lab_results",
      where: not is_nil(b.numeric_value),
      order_by: [asc: d.document_date, asc: d.inserted_at],
      select: %{
        name: b.name,
        unit: b.unit,
        numeric_value: b.numeric_value,
        status: b.status,
        document_date: d.document_date,
        document_id: d.id
      }
    )
    |> Repo.all()
    |> Enum.group_by(&{&1.name, normalize_unit(&1.unit)})
  end

  @doc """
  Normalizes a biomarker unit by stripping trailing markers (e.g. `*`).

  This ensures "%" and "%*", or "tys/μl" and "tys/μl*" are treated as the same unit.
  """
  def normalize_unit(nil), do: nil
  def normalize_unit(unit), do: String.replace(unit, ~r/\*+$/, "")
end
