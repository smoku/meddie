defmodule Meddie.Workers.ParseDocumentTest do
  use Meddie.DataCase, async: true
  use Oban.Testing, repo: Meddie.Repo

  alias Meddie.Documents
  alias Meddie.Workers.ParseDocument

  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.DocumentsFixtures

  setup do
    %{scope: scope} = fixture = user_with_space_fixture()
    person = person_fixture(scope)

    # Write a test file for the storage to return
    storage_path = "documents/test/#{Ecto.UUID.generate()}/test.jpg"
    :ok = Meddie.Storage.put(storage_path, "fake image data", "image/jpeg")

    doc =
      document_fixture(scope, person, %{
        "content_type" => "image/jpeg",
        "storage_path" => storage_path
      })

    Map.merge(fixture, %{person: person, document: doc, storage_path: storage_path})
  end

  describe "perform/1" do
    test "successfully parses document and creates biomarkers", %{
      document: doc,
      scope: scope
    } do
      assert :ok = perform_job(ParseDocument, %{document_id: doc.id})

      updated = Documents.get_document!(scope, doc.id)
      assert updated.status == "parsed"
      assert updated.document_type == "lab_results"
      assert updated.summary == "Blood work results showing normal values."
      assert updated.document_date == ~D[2025-01-15]

      # Mock returns 2 biomarkers
      assert length(updated.biomarkers) == 2
      names = Enum.map(updated.biomarkers, & &1.name)
      assert "Hemoglobina" in names
      assert "WBC" in names
    end

    test "broadcasts document updates", %{document: doc, person: person} do
      Documents.subscribe_person_documents(person.id)

      perform_job(ParseDocument, %{document_id: doc.id})

      # Should receive parsing status and then parsed status
      assert_received {:document_updated, %{status: "parsing"}}
      assert_received {:document_updated, %{status: "parsed"}}
    end

    test "sets biomarker foreign keys correctly", %{document: doc, scope: scope} do
      perform_job(ParseDocument, %{document_id: doc.id})

      updated = Documents.get_document!(scope, doc.id)

      for bm <- updated.biomarkers do
        assert bm.document_id == doc.id
        assert bm.space_id == doc.space_id
        assert bm.person_id == doc.person_id
      end
    end
  end

  describe "backoff/1" do
    test "returns exponential backoff values" do
      assert ParseDocument.backoff(%Oban.Job{attempt: 1}) == 5
      assert ParseDocument.backoff(%Oban.Job{attempt: 2}) == 30
      assert ParseDocument.backoff(%Oban.Job{attempt: 3}) == 180
    end
  end
end
