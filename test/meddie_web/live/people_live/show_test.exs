defmodule MeddieWeb.PeopleLive.ShowTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures

  defp create_person_with_space(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})

    person =
      person_fixture(scope, %{
        "name" => "Anna Nowak",
        "sex" => "female",
        "date_of_birth" => "1990-05-15",
        "height_cm" => "170",
        "weight_kg" => "65.5"
      })

    %{user: user, space: space, scope: scope, person: person}
  end

  describe "Show" do
    setup [:create_person_with_space]

    test "renders person details", %{conn: conn, user: user, space: space, person: person} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}")

      assert html =~ person.name
      assert html =~ "Female"
      assert html =~ "170 cm"
      assert html =~ "65.5 kg"
      assert html =~ "1990-05-15"
    end

    test "renders markdown fields", %{
      conn: conn,
      user: user,
      space: space,
      scope: scope,
      person: person
    } do
      {:ok, updated} =
        Meddie.People.update_person(scope, person, %{
          "health_notes" => "Diabetes type 2",
          "supplements" => "Vitamin D 2000 IU",
          "medications" => "Metformin 500mg"
        })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{updated}")

      assert html =~ "Diabetes type 2"
      assert html =~ "Vitamin D 2000 IU"
      assert html =~ "Metformin 500mg"
    end

    test "shows empty state for unset markdown fields", %{
      conn: conn,
      user: user,
      space: space,
      person: person
    } do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}")

      assert html =~ "—"
    end

    test "deletes person and redirects to index", %{
      conn: conn,
      user: user,
      space: space,
      person: person
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}")

      assert lv |> element("button[phx-click=delete]") |> has_element?()

      lv
      |> element("button[phx-click=delete]")
      |> render_click()

      flash = assert_redirect(lv, ~p"/people")
      assert flash["info"] == "Person deleted successfully."
    end
  end
end
