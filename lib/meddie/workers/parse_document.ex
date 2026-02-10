defmodule Meddie.Workers.ParseDocument do
  @moduledoc """
  Oban worker that parses medical documents using AI vision models.
  Handles the full pipeline: fetch file → prepare images → AI call → save results.
  """

  use Oban.Worker,
    queue: :document_parsing,
    max_attempts: 3

  alias Meddie.Documents
  alias Meddie.Documents.PdfRenderer
  alias Meddie.AI
  alias Meddie.AI.Prompts
  alias Meddie.Storage

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"document_id" => document_id},
        attempt: attempt,
        max_attempts: max_attempts
      }) do
    document = Documents.get_document!(document_id)
    person = document.person

    # Update status to parsing
    {:ok, document} = Documents.update_document(document, %{"status" => "parsing"})
    Documents.broadcast_document_update(document)

    case do_parse(document, person) do
      {:ok, document} ->
        Documents.broadcast_document_update(document)
        :ok

      {:error, reason} ->
        Logger.error("Document parsing failed (attempt #{attempt}/#{max_attempts}): #{reason}")

        status = if attempt >= max_attempts, do: "failed", else: "pending"

        {:ok, updated} =
          Documents.update_document(document, %{
            "status" => status,
            "error_message" => reason
          })

        Documents.broadcast_document_update(updated)
        {:error, reason}
    end
  end

  defp do_parse(document, person) do
    with {:ok, file_data} <- Storage.get(document.storage_path),
         {:ok, images} <- prepare_images(document, file_data),
         person_context = Prompts.person_context(person),
         {:ok, result} <- AI.parse_document(images, person_context) do
      save_results(document, result)
    end
  end

  defp prepare_images(%{content_type: "application/pdf"} = document, file_data) do
    case PdfRenderer.render_pages(file_data) do
      {:ok, pages} ->
        Documents.update_document(document, %{"page_count" => length(pages)})
        images = Enum.map(pages, fn {_page_num, data} -> {data, "image/png"} end)
        {:ok, images}

      {:error, reason} ->
        {:error, "PDF rendering failed: #{reason}"}
    end
  end

  defp prepare_images(%{content_type: content_type}, file_data)
       when content_type in ["image/jpeg", "image/png"] do
    {:ok, [{file_data, content_type}]}
  end

  defp prepare_images(%{content_type: content_type}, _file_data) do
    {:error, "Unsupported content type: #{content_type}"}
  end

  defp save_results(document, result) do
    attrs = %{
      "status" => "parsed",
      "document_type" => result["document_type"] || "other",
      "summary" => result["summary"],
      "document_date" => result["document_date"],
      "error_message" => nil
    }

    {:ok, updated} = Documents.update_document(document, attrs)

    if result["document_type"] == "lab_results" && is_list(result["biomarkers"]) do
      biomarkers =
        result["biomarkers"]
        |> deduplicate_biomarkers()
        |> Enum.map(&normalize_biomarker/1)

      Documents.create_biomarkers(updated, biomarkers)
    end

    # Reload with biomarkers for broadcast
    updated = Meddie.Repo.preload(updated, :biomarkers, force: true)
    {:ok, updated}
  end

  defp deduplicate_biomarkers(biomarkers) do
    biomarkers
    |> Enum.group_by(fn b -> {b["name"], b["value"]} end)
    |> Enum.map(fn {_key, dupes} ->
      Enum.max_by(dupes, fn b ->
        Enum.count(b, fn {_k, v} -> v != nil end)
      end)
    end)
  end

  defp normalize_biomarker(data) do
    %{
      name: data["name"],
      value: data["value"],
      numeric_value: data["numeric_value"],
      unit: data["unit"],
      reference_range_low: data["reference_range_low"],
      reference_range_high: data["reference_range_high"],
      reference_range_text: data["reference_range_text"],
      status: data["status"] || "unknown",
      page_number: data["page_number"],
      category: data["category"]
    }
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    case attempt do
      1 -> 5
      2 -> 30
      _ -> 180
    end
  end
end
