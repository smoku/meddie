defmodule MeddieWeb.AskMeddieLive.ShowTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures
  import Meddie.ConversationsFixtures

  defp create_user_with_space_and_person(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})

    person =
      person_fixture(scope, %{
        "name" => "Anna Nowak",
        "sex" => "female",
        "date_of_birth" => "1990-05-15"
      })

    %{user: user, space: space, scope: scope, person: person}
  end

  describe "New conversation" do
    setup [:create_user_with_space_and_person]

    test "renders new conversation page", %{conn: conn, user: user, space: space} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/new")

      assert html =~ "New conversation"
      assert html =~ "Start a conversation with Meddie"
    end

    test "pre-selects person from query param", %{conn: conn, user: user, space: space, person: person} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/new?person_id=#{person.id}")

      assert html =~ person.name
      assert html =~ "Ask Meddie about"
    end

    test "shows quick questions when person selected", %{conn: conn, user: user, space: space, person: person} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/new?person_id=#{person.id}")

      assert html =~ "Summarize my latest results"
      assert html =~ "What should I watch out for?"
      assert html =~ "Explain my out-of-range values"
    end

    test "person picker lists all people", %{conn: conn, user: user, space: space, scope: scope, person: person} do
      person2 = person_fixture(scope, %{"name" => "Jan Kowalski", "sex" => "male"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/new")

      assert html =~ person.name
      assert html =~ person2.name
    end
  end

  describe "Existing conversation" do
    setup [:create_user_with_space_and_person]

    test "renders existing conversation with messages", %{conn: conn, user: user, space: space, scope: scope, person: person} do
      conv = conversation_fixture(scope, %{"title" => "Test chat", "person_id" => person.id})
      message_fixture(conv, %{"role" => "user", "content" => "Hello Meddie"})
      message_fixture(conv, %{"role" => "assistant", "content" => "Hello! How can I help?"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/#{conv}")

      assert html =~ "Test chat"
      assert html =~ "Hello Meddie"
      assert html =~ "How can I help?"
    end

    test "shows person name for conversation with person", %{conn: conn, user: user, space: space, scope: scope, person: person} do
      conv = conversation_fixture(scope, %{"person_id" => person.id})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/#{conv}")

      assert html =~ person.name
    end

    test "delete conversation redirects to index", %{conn: conn, user: user, space: space, scope: scope} do
      conv = conversation_fixture(scope, %{"title" => "To delete"})
      auth_conn = log_in_user(conn, user, space: space)

      {:ok, lv, _html} = live(auth_conn, ~p"/ask-meddie/#{conv}")

      assert {:ok, _lv, html} =
               lv
               |> element("button[phx-click='delete_conversation']")
               |> render_click()
               |> follow_redirect(auth_conn)

      refute html =~ "To delete"
    end

    test "cannot access other user's conversation", %{conn: conn, user: user, space: space} do
      other = Meddie.AccountsFixtures.user_fixture(%{locale: "en"})
      Meddie.Repo.insert!(%Meddie.Spaces.Membership{space_id: space.id, user_id: other.id, role: "member"})
      other_scope = Meddie.Accounts.Scope.for_user(other) |> Meddie.Accounts.Scope.put_space(space)
      conv = conversation_fixture(other_scope, %{"title" => "Private chat"})

      assert_raise Ecto.NoResultsError, fn ->
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/#{conv}")
      end
    end
  end

  describe "Sending messages" do
    setup [:create_user_with_space_and_person]

    test "send_message creates user message and starts streaming", %{conn: conn, user: user, space: space, person: person} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/new?person_id=#{person.id}")

      html =
        lv
        |> form("form", %{"message" => "What are my latest results?"})
        |> render_submit()

      # Should show the user message and streaming indicator
      assert html =~ "What are my latest results?"
      assert html =~ "loading"
    end

    test "empty message is ignored", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie/new")

      html =
        lv
        |> form("form", %{"message" => "  "})
        |> render_submit()

      # Should still show the empty state
      assert html =~ "Start a conversation with Meddie"
    end
  end
end
