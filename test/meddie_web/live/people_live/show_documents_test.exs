defmodule MeddieWeb.PeopleLive.ShowDocumentsTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.DocumentsFixtures

  defp create_person_with_space(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})

    person =
      person_fixture(scope, %{
        "name" => "Anna Nowak",
        "sex" => "female",
        "date_of_birth" => "1990-05-15"
      })

    %{user: user, space: space, scope: scope, person: person}
  end

  describe "Documents tab" do
    setup [:create_person_with_space]

    test "renders tab navigation", %{conn: conn, user: user, space: space, person: person} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}")

      assert html =~ "Overview"
      assert html =~ "Documents"
    end

    test "switches to documents tab", %{conn: conn, user: user, space: space, person: person} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}")

      html = lv |> element(~s|a[href*="tab=documents"]|) |> render_click()

      assert html =~ "No documents yet."
      assert html =~ "Upload a medical document to get started."
      assert html =~ "Browse files"
      assert html =~ "Drag and drop files here, or"
    end

    test "defaults to overview tab", %{conn: conn, user: user, space: space, person: person} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}")

      assert html =~ "Profile"
      assert html =~ "Anna Nowak"
    end

    test "navigates directly to documents tab via URL param", %{
      conn: conn,
      user: user,
      space: space,
      person: person
    } do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}?tab=documents")

      assert html =~ "No documents yet."
    end

    test "renders document list with pending document", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      document_fixture(scope, person, %{"filename" => "blood_test.pdf"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}?tab=documents")

      assert html =~ "blood_test.pdf"
      assert html =~ "Pending"
    end

    test "renders parsed document with biomarker count", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc = parsed_document_fixture(scope, person)
      biomarker_fixture(doc, %{name: "Hemoglobina"})
      biomarker_fixture(doc, %{name: "WBC"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}?tab=documents")

      assert html =~ "Parsed"
      assert html =~ "2 biomarkers"
    end

    test "shows documents count badge on tab", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      document_fixture(scope, person)
      document_fixture(scope, person)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}")

      # Badge shows "2"
      assert html =~ ~r/badge.*2/s
    end

    test "document links to document detail", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc = document_fixture(scope, person)

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}?tab=documents")

      assert html =~ ~p"/people/#{person}/documents/#{doc}"
    end

    test "updates document list via PubSub", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc = document_fixture(scope, person)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}?tab=documents")

      {:ok, updated} =
        Meddie.Documents.update_document(doc, %{
          "status" => "parsed",
          "document_type" => "lab_results"
        })

      updated = Meddie.Repo.preload(updated, :biomarkers)

      send(lv.pid, {:document_updated, updated})

      html = render(lv)
      assert html =~ "Parsed"
    end
  end
end
