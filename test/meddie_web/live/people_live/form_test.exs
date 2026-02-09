defmodule MeddieWeb.PeopleLive.FormTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures

  defp create_user_with_space(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})
    %{user: user, space: space, scope: scope}
  end

  describe "New" do
    setup [:create_user_with_space]

    test "renders new person form", %{conn: conn, user: user, space: space} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/new")

      assert html =~ "Add person"
      assert html =~ "Basic information"
      refute html =~ "Health information"
    end

    test "validates form on change", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/new")

      result =
        lv
        |> form("#person-form", %{"person" => %{"name" => "", "sex" => ""}})
        |> render_change()

      assert result =~ "can&#39;t be blank"
    end

    test "creates person and redirects to show page", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/new")

      lv
      |> form("#person-form", %{
        "person" => %{
          "name" => "Jan Kowalski",
          "sex" => "male",
          "date_of_birth" => "1985-03-20",
          "height_cm" => "180",
          "weight_kg" => "80"
        }
      })
      |> render_submit()

      {path, flash} = assert_redirect(lv)
      assert path =~ ~r"/people/"
      assert flash["info"] == "Person created successfully."
    end

    test "creates person linked to user account", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/new")

      lv
      |> form("#person-form", %{
        "person" => %{
          "name" => "Me Myself",
          "sex" => "female",
          "user_id" => user.id
        }
      })
      |> render_submit()

      {path, flash} = assert_redirect(lv)
      assert path =~ ~r"/people/"
      assert flash["info"] == "Person created successfully."
    end

    test "shows errors on invalid submit", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/new")

      result =
        lv
        |> form("#person-form", %{"person" => %{"name" => "", "sex" => ""}})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    setup [:create_user_with_space]

    setup %{scope: scope} do
      person = person_fixture(scope, %{"name" => "Original Name", "sex" => "female"})
      %{person: person}
    end

    test "renders edit form with existing data", %{
      conn: conn,
      user: user,
      space: space,
      person: person
    } do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/edit")

      assert html =~ "Edit person"
      assert html =~ "Original Name"
      assert html =~ "Health information"
    end

    test "updates person and redirects to show page", %{
      conn: conn,
      user: user,
      space: space,
      person: person
    } do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/edit")

      lv
      |> form("#person-form", %{
        "person" => %{
          "name" => "Updated Name",
          "health_notes" => "Some health notes"
        }
      })
      |> render_submit()

      flash = assert_redirect(lv, ~p"/people/#{person}")
      assert flash["info"] == "Person updated successfully."
    end

    test "shows markdown fields in edit mode", %{
      conn: conn,
      user: user,
      space: space,
      person: person
    } do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/people/#{person}/edit")

      assert html =~ "Health Notes"
      assert html =~ "Supplements"
      assert html =~ "Medications"
    end
  end
end
