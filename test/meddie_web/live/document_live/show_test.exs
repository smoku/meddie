defmodule MeddieWeb.DocumentLive.ShowTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.DocumentsFixtures

  defp create_document_with_context(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})

    person =
      person_fixture(scope, %{
        "name" => "Anna Nowak",
        "sex" => "female"
      })

    document = document_fixture(scope, person)

    %{user: user, space: space, scope: scope, person: person, document: document}
  end

  describe "Document Show" do
    setup [:create_document_with_context]

    test "renders document header", %{
      conn: conn,
      user: user,
      space: space,
      person: person,
      document: document
    } do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{document}")

      assert html =~ document.filename
      assert html =~ "Uploaded"
    end

    test "renders pending status", %{
      conn: conn,
      user: user,
      space: space,
      person: person,
      document: document
    } do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{document}")

      assert html =~ "Waiting to be parsed..."
    end

    test "renders parsing status", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc = document_fixture(scope, person, %{"status" => "parsing"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{doc}")

      assert html =~ "Parsing document..."
    end

    test "renders failed status with retry button", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc =
        document_fixture(scope, person, %{
          "status" => "failed",
          "error_message" => "AI service unavailable"
        })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{doc}")

      assert html =~ "Parsing failed"
      assert html =~ "AI service unavailable"
      assert html =~ "Retry"
    end

    test "renders parsed lab results with biomarker table", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc =
        parsed_document_fixture(scope, person, %{
          "summary" => "Normal blood work results."
        })

      biomarker_fixture(doc, %{
        name: "Hemoglobina",
        value: "14.5",
        unit: "g/dL",
        status: "normal",
        category: "Morfologia krwi"
      })

      biomarker_fixture(doc, %{
        name: "WBC",
        value: "3.2",
        unit: "10^3/uL",
        status: "low",
        category: "Morfologia krwi"
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{doc}")

      assert html =~ "Normal blood work results."
      assert html =~ "Morfologia krwi"
      assert html =~ "Hemoglobina"
      assert html =~ "14.5"
      assert html =~ "g/dL"
      assert html =~ "WBC"
      assert html =~ "normal"
      assert html =~ "low"
    end

    test "renders parsed medical report with summary", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc =
        document_fixture(scope, person, %{
          "status" => "parsed",
          "document_type" => "medical_report",
          "summary" => "Patient shows signs of improvement."
        })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{doc}")

      assert html =~ "Summary"
      assert html =~ "Patient shows signs of improvement."
    end

    test "switches panels on mobile", %{
      conn: conn,
      user: user,
      space: space,
      person: person,
      document: document
    } do
      {:ok, lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{document}")

      # Default panel is results
      assert html =~ "Results"
      assert html =~ "Original"

      # Switch to original
      html = lv |> element(~s|button[phx-value-panel="original"]|) |> render_click()
      assert html =~ "Original"
    end

    test "deletes document and redirects", %{
      conn: conn,
      user: user,
      space: space,
      person: person,
      document: document
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{document}")

      assert lv |> element("button[phx-click=delete]") |> has_element?()

      lv
      |> element("button[phx-click=delete]")
      |> render_click()

      flash = assert_redirect(lv, ~p"/people/#{person}?tab=documents")
      assert flash["info"] == "Document deleted successfully."
    end

    test "updates document via PubSub", %{
      conn: conn,
      user: user,
      space: space,
      person: person,
      document: document
    } do
      {:ok, lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{document}")

      assert html =~ "Waiting to be parsed..."

      {:ok, updated} =
        Meddie.Documents.update_document(document, %{"status" => "parsing"})

      send(lv.pid, {:document_updated, updated})

      html = render(lv)
      assert html =~ "Parsing document..."
    end

    test "does not crash on PDF content type", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc =
        document_fixture(scope, person, %{
          "content_type" => "application/pdf",
          "filename" => "test.pdf"
        })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{doc}")

      assert html =~ "pdf-viewer"
      assert html =~ "PdfViewer"
    end

    test "renders image for non-PDF content type", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      doc =
        document_fixture(scope, person, %{
          "content_type" => "image/jpeg",
          "filename" => "scan.jpg"
        })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/documents/#{doc}")

      assert html =~ "<img"
      assert html =~ "scan.jpg"
    end
  end
end
