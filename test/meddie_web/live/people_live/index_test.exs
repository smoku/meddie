defmodule MeddieWeb.PeopleLive.IndexTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures

  defp create_user_with_space(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})
    %{user: user, space: space, scope: scope}
  end

  describe "Index" do
    setup [:create_user_with_space]

    test "renders empty state when no people exist", %{conn: conn, user: user, space: space} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people")

      assert html =~ "People"
      assert html =~ "No people yet."
      assert html =~ "Add your first person to start tracking health data."
    end

    test "lists people", %{conn: conn, user: user, space: space, scope: scope} do
      person = person_fixture(scope, %{"name" => "Jan Kowalski", "sex" => "male"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people")

      assert html =~ person.name
      assert html =~ "Male"
    end

    test "navigates to person show page", %{conn: conn, user: user, space: space, scope: scope} do
      person = person_fixture(scope)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people")

      assert lv
             |> element("#people-#{person.id}")
             |> has_element?()
    end

    test "redirects to login if not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/people")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
    end
  end
end
