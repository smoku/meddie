defmodule Meddie.DocumentsTest do
  use Meddie.DataCase, async: true

  alias Meddie.Documents
  alias Meddie.Documents.{Document, Biomarker}

  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.DocumentsFixtures

  setup do
    %{scope: scope} = fixture = user_with_space_fixture()
    person = person_fixture(scope)
    Map.merge(fixture, %{person: person})
  end

  describe "list_documents/3" do
    test "returns documents for a person in scope", %{scope: scope, person: person} do
      doc1 = document_fixture(scope, person)
      doc2 = document_fixture(scope, person)

      docs = Documents.list_documents(scope, person.id)
      ids = Enum.map(docs, & &1.id)

      assert length(ids) == 2
      assert doc1.id in ids
      assert doc2.id in ids
    end

    test "does not return documents from another space", %{person: person} do
      %{scope: other_scope} = user_with_space_fixture()
      other_person = person_fixture(other_scope)
      _other_doc = document_fixture(other_scope, other_person)

      %{scope: scope} = user_with_space_fixture()
      docs = Documents.list_documents(scope, person.id)
      assert docs == []
    end

    test "supports pagination via :limit and :offset", %{scope: scope, person: person} do
      for _ <- 1..5, do: document_fixture(scope, person)

      page1 = Documents.list_documents(scope, person.id, limit: 2, offset: 0)
      page2 = Documents.list_documents(scope, person.id, limit: 2, offset: 2)

      assert length(page1) == 2
      assert length(page2) == 2
      assert Enum.map(page1, & &1.id) -- Enum.map(page2, & &1.id) == Enum.map(page1, & &1.id)
    end
  end

  describe "get_document!/2 (scoped)" do
    test "returns the document with biomarkers preloaded", %{scope: scope, person: person} do
      doc = parsed_document_fixture(scope, person)
      _bm = biomarker_fixture(doc)

      fetched = Documents.get_document!(scope, doc.id)
      assert fetched.id == doc.id
      assert length(fetched.biomarkers) == 1
      assert hd(fetched.biomarkers).name == "Hemoglobina"
    end

    test "raises for document in another space", %{scope: scope, person: person} do
      doc = document_fixture(scope, person)

      %{scope: other_scope} = user_with_space_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document!(other_scope, doc.id)
      end
    end
  end

  describe "get_document!/1 (no scope)" do
    test "returns document with person preloaded", %{scope: scope, person: person} do
      doc = document_fixture(scope, person)

      fetched = Documents.get_document!(doc.id)
      assert fetched.id == doc.id
      assert fetched.person.id == person.id
    end
  end

  describe "create_document/3" do
    test "creates a document with valid attributes", %{scope: scope, person: person} do
      attrs = valid_document_attributes()
      assert {:ok, %Document{} = doc} = Documents.create_document(scope, person.id, attrs)
      assert doc.filename == attrs["filename"]
      assert doc.status == "pending"
      assert doc.space_id == scope.space.id
      assert doc.person_id == person.id
    end

    test "returns error changeset for missing required fields", %{scope: scope, person: person} do
      assert {:error, %Ecto.Changeset{}} = Documents.create_document(scope, person.id, %{})
    end

    test "rejects invalid status", %{scope: scope, person: person} do
      attrs = valid_document_attributes(%{"status" => "invalid"})
      assert {:error, changeset} = Documents.create_document(scope, person.id, attrs)
      assert errors_on(changeset).status != nil
    end
  end

  describe "update_document/2" do
    test "updates status and summary", %{scope: scope, person: person} do
      doc = document_fixture(scope, person)

      assert {:ok, updated} =
               Documents.update_document(doc, %{
                 "status" => "parsed",
                 "summary" => "Test summary",
                 "document_type" => "lab_results"
               })

      assert updated.status == "parsed"
      assert updated.summary == "Test summary"
    end
  end

  describe "delete_document/2" do
    test "deletes the document and cascades biomarkers", %{scope: scope, person: person} do
      doc = parsed_document_fixture(scope, person)
      _bm = biomarker_fixture(doc)

      assert {:ok, _} = Documents.delete_document(scope, doc)

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document!(scope, doc.id)
      end

      assert Repo.all(from(b in Biomarker, where: b.document_id == ^doc.id)) == []
    end
  end

  describe "create_biomarkers/2" do
    test "bulk inserts biomarkers for a document", %{scope: scope, person: person} do
      doc = document_fixture(scope, person)

      biomarkers = [
        biomarker_attrs(%{name: "Hemoglobina", value: "14,5"}),
        biomarker_attrs(%{name: "WBC", value: "6,8", category: "Morfologia krwi"})
      ]

      assert {2, _} = Documents.create_biomarkers(doc, biomarkers)

      fetched = Documents.get_document!(scope, doc.id)
      assert length(fetched.biomarkers) == 2
    end

    test "sets correct foreign keys on biomarkers", %{scope: scope, person: person} do
      doc = document_fixture(scope, person)
      {1, _} = Documents.create_biomarkers(doc, [biomarker_attrs()])

      [bm] = Repo.all(from(b in Biomarker, where: b.document_id == ^doc.id))
      assert bm.document_id == doc.id
      assert bm.space_id == doc.space_id
      assert bm.person_id == doc.person_id
    end
  end

  describe "count_documents/2" do
    test "returns the correct count", %{scope: scope, person: person} do
      assert Documents.count_documents(scope, person.id) == 0

      document_fixture(scope, person)
      document_fixture(scope, person)

      assert Documents.count_documents(scope, person.id) == 2
    end
  end

  describe "document_exists_by_hash?/3" do
    test "returns false when no document with hash exists", %{scope: scope, person: person} do
      refute Documents.document_exists_by_hash?(scope, person.id, "abc123")
    end

    test "returns true when document with same hash exists for same person", %{
      scope: scope,
      person: person
    } do
      hash = "deadbeef" <> Integer.to_string(System.unique_integer([:positive]))
      document_fixture(scope, person, %{"content_hash" => hash})

      assert Documents.document_exists_by_hash?(scope, person.id, hash)
    end

    test "returns false for same hash but different person", %{scope: scope} do
      hash = "samehash" <> Integer.to_string(System.unique_integer([:positive]))
      person1 = person_fixture(scope, %{"name" => "Person A"})
      person2 = person_fixture(scope, %{"name" => "Person B"})

      document_fixture(scope, person1, %{"content_hash" => hash})

      refute Documents.document_exists_by_hash?(scope, person2.id, hash)
    end
  end

  describe "content_hash unique constraint" do
    test "prevents duplicate hash for same person", %{scope: scope, person: person} do
      hash = "unique_hash_" <> Integer.to_string(System.unique_integer([:positive]))
      document_fixture(scope, person, %{"content_hash" => hash})

      attrs = valid_document_attributes(%{"content_hash" => hash})
      assert {:error, changeset} = Documents.create_document(scope, person.id, attrs)
      assert errors_on(changeset).content_hash == ["duplicate document"]
    end

    test "allows same hash for different people", %{scope: scope} do
      hash = "shared_hash_" <> Integer.to_string(System.unique_integer([:positive]))
      person1 = person_fixture(scope, %{"name" => "Person X"})
      person2 = person_fixture(scope, %{"name" => "Person Y"})

      document_fixture(scope, person1, %{"content_hash" => hash})

      attrs = valid_document_attributes(%{"content_hash" => hash})
      assert {:ok, _} = Documents.create_document(scope, person2.id, attrs)
    end
  end

  describe "PubSub" do
    test "broadcast_document_update/1 sends message to subscribers", %{
      scope: scope,
      person: person
    } do
      doc = document_fixture(scope, person)
      Documents.subscribe_person_documents(person.id)

      Documents.broadcast_document_update(doc)

      assert_receive {:document_updated, ^doc}
    end
  end

  describe "list_person_biomarkers/2" do
    test "returns biomarkers from parsed lab_results ordered by category, name, date", %{
      scope: scope,
      person: person
    } do
      doc1 = parsed_document_fixture(scope, person, %{"document_date" => ~D[2025-01-15]})
      doc2 = parsed_document_fixture(scope, person, %{"document_date" => ~D[2025-06-15]})

      biomarker_fixture(doc1, %{name: "WBC", value: "6.0", numeric_value: 6.0, category: "CBC"})
      biomarker_fixture(doc2, %{name: "WBC", value: "7.0", numeric_value: 7.0, category: "CBC"})
      biomarker_fixture(doc1, %{name: "ALT", value: "25", numeric_value: 25.0, category: "Liver"})

      results = Documents.list_person_biomarkers(scope, person.id)

      names = Enum.map(results, & &1.name)
      # Ordered by category (CBC < Liver), then name, then date
      assert names == ["WBC", "WBC", "ALT"]
    end

    test "only includes biomarkers from parsed lab_results", %{scope: scope, person: person} do
      parsed_doc = parsed_document_fixture(scope, person)
      pending_doc = document_fixture(scope, person)

      biomarker_fixture(parsed_doc, %{name: "HGB", value: "14.5"})
      biomarker_fixture(pending_doc, %{name: "WBC", value: "6.0"})

      results = Documents.list_person_biomarkers(scope, person.id)
      assert length(results) == 1
      assert hd(results).name == "HGB"
    end

    test "preloads document", %{scope: scope, person: person} do
      doc = parsed_document_fixture(scope, person)
      biomarker_fixture(doc)

      [bm] = Documents.list_person_biomarkers(scope, person.id)
      assert %Meddie.Documents.Document{} = bm.document
    end

    test "scopes to space", %{scope: scope, person: person} do
      doc = parsed_document_fixture(scope, person)
      biomarker_fixture(doc)

      %{scope: other_scope} = user_with_space_fixture()
      assert Documents.list_person_biomarkers(other_scope, person.id) == []
    end
  end

  describe "count_person_biomarkers_by_status/2" do
    test "returns counts grouped by status", %{scope: scope, person: person} do
      doc = parsed_document_fixture(scope, person)

      biomarker_fixture(doc, %{name: "HGB", status: "normal"})
      biomarker_fixture(doc, %{name: "WBC", status: "normal"})
      biomarker_fixture(doc, %{name: "ALT", status: "high"})
      biomarker_fixture(doc, %{name: "Iron", status: "low"})

      counts = Documents.count_person_biomarkers_by_status(scope, person.id)

      assert counts["normal"] == 2
      assert counts["high"] == 1
      assert counts["low"] == 1
    end

    test "returns empty map when no biomarkers", %{scope: scope, person: person} do
      assert Documents.count_person_biomarkers_by_status(scope, person.id) == %{}
    end
  end

  describe "list_biomarker_history/3" do
    test "returns history grouped by name with numeric values only", %{
      scope: scope,
      person: person
    } do
      doc1 = parsed_document_fixture(scope, person, %{"document_date" => ~D[2025-01-15]})
      doc2 = parsed_document_fixture(scope, person, %{"document_date" => ~D[2025-06-15]})

      biomarker_fixture(doc1, %{name: "HGB", value: "14.0", numeric_value: 14.0})
      biomarker_fixture(doc2, %{name: "HGB", value: "15.0", numeric_value: 15.0})
      biomarker_fixture(doc1, %{name: "RBC", value: "Positive", numeric_value: nil})

      history = Documents.list_biomarker_history(scope, person.id, ["HGB", "RBC"])

      assert Map.has_key?(history, {"HGB", "g/dL"})
      assert length(history[{"HGB", "g/dL"}]) == 2
      # RBC excluded because numeric_value is nil
      refute Enum.any?(Map.keys(history), fn {name, _unit} -> name == "RBC" end)
    end

    test "returns empty map for no matching names", %{scope: scope, person: person} do
      assert Documents.list_biomarker_history(scope, person.id, ["Nonexistent"]) == %{}
    end

    test "orders by document date ascending", %{scope: scope, person: person} do
      doc_old = parsed_document_fixture(scope, person, %{"document_date" => ~D[2024-01-01]})
      doc_new = parsed_document_fixture(scope, person, %{"document_date" => ~D[2025-06-01]})

      biomarker_fixture(doc_new, %{name: "HGB", value: "15.0", numeric_value: 15.0})
      biomarker_fixture(doc_old, %{name: "HGB", value: "14.0", numeric_value: 14.0})

      history = Documents.list_biomarker_history(scope, person.id, ["HGB"])
      values = Enum.map(history[{"HGB", "g/dL"}], & &1.numeric_value)

      assert values == [14.0, 15.0]
    end
  end
end
