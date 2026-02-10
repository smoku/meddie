defmodule Meddie.DocumentsFixtures do
  @moduledoc """
  Test helpers for creating Documents and Biomarkers.
  """

  alias Meddie.Documents

  def valid_document_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "filename" => "test_lab_#{System.unique_integer([:positive])}.pdf",
      "content_type" => "application/pdf",
      "file_size" => 1_024_000,
      "storage_path" => "documents/test/#{Ecto.UUID.generate()}/test.pdf"
    })
  end

  def document_fixture(scope, person, attrs \\ %{}) do
    {:ok, document} =
      Documents.create_document(scope, person.id, valid_document_attributes(attrs))

    document
  end

  def parsed_document_fixture(scope, person, attrs \\ %{}) do
    doc_attrs =
      Map.merge(
        %{
          "status" => "parsed",
          "document_type" => "lab_results",
          "summary" => "Blood work results showing normal values."
        },
        attrs
      )

    document = document_fixture(scope, person, doc_attrs)
    document
  end

  def biomarker_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        name: "Hemoglobina",
        value: "14,5",
        numeric_value: 14.5,
        unit: "g/dL",
        reference_range_low: 12.0,
        reference_range_high: 16.0,
        reference_range_text: "12,0 - 16,0",
        status: "normal",
        category: "Morfologia krwi"
      },
      overrides
    )
  end

  def biomarker_fixture(document, overrides \\ %{}) do
    {1, _} = Documents.create_biomarkers(document, [biomarker_attrs(overrides)])

    import Ecto.Query

    Meddie.Repo.one!(
      from(b in Meddie.Documents.Biomarker,
        where: b.document_id == ^document.id,
        order_by: [desc: b.inserted_at],
        limit: 1
      )
    )
  end
end
