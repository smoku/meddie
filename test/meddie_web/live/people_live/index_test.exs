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

    test "redirects to /people/new when no people exist", %{conn: conn, user: user, space: space} do
      assert {:error, {:live_redirect, %{to: "/people/new"}}} =
               conn
               |> log_in_user(user, space: space)
               |> live(~p"/people")
    end

    test "redirects to first person when people exist", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope
    } do
      person = person_fixture(scope, %{"name" => "Jan Kowalski", "sex" => "male"})

      assert {:error, {:live_redirect, %{to: "/people/" <> id}}} =
               conn
               |> log_in_user(user, space: space)
               |> live(~p"/people")

      assert id == person.id
    end

    test "redirects to login if not authenticated", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/people")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log-in"
    end
  end
end
