defmodule MeddieWeb.AskMeddieLive.IndexTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures
  import Meddie.ConversationsFixtures

  defp create_user_with_space(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})
    %{user: user, space: space, scope: scope}
  end

  describe "Index" do
    setup [:create_user_with_space]

    test "renders empty state when no conversations", %{conn: conn, user: user, space: space} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie")

      assert html =~ "No conversations yet."
      assert html =~ "New chat"
    end

    test "renders conversation list", %{conn: conn, user: user, space: space, scope: scope} do
      _conv = conversation_fixture(scope, %{"title" => "My health question"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie")

      assert html =~ "My health question"
    end

    test "navigates to new chat", %{conn: conn, user: user, space: space} do
      auth_conn = log_in_user(conn, user, space: space)

      {:ok, lv, _html} = live(auth_conn, ~p"/ask-meddie")

      assert {:ok, _lv, _html} =
               lv
               |> element("a", "New chat")
               |> render_click()
               |> follow_redirect(auth_conn)
    end

    test "navigates to existing conversation", %{conn: conn, user: user, space: space, scope: scope} do
      conv = conversation_fixture(scope, %{"title" => "Test conversation"})
      auth_conn = log_in_user(conn, user, space: space)

      {:ok, lv, _html} = live(auth_conn, ~p"/ask-meddie")

      assert {:ok, _lv, html} =
               lv
               |> element("aside a[href='/ask-meddie/#{conv.id}']")
               |> render_click()
               |> follow_redirect(auth_conn)

      assert html =~ "Test conversation"
    end

    test "does not show other user's conversations", %{conn: conn, user: user, space: space} do
      # Create another user with their own conversation in the same space
      other = Meddie.AccountsFixtures.user_fixture(%{locale: "en"})
      Meddie.Repo.insert!(%Meddie.Spaces.Membership{space_id: space.id, user_id: other.id, role: "member"})
      other_scope = Meddie.Accounts.Scope.for_user(other) |> Meddie.Accounts.Scope.put_space(space)
      conversation_fixture(other_scope, %{"title" => "Other user's chat"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/ask-meddie")

      refute html =~ "Other user's chat"
    end
  end
end
