defmodule Meddie.PeopleTest do
  use Meddie.DataCase, async: true

  alias Meddie.People
  alias Meddie.People.Person

  import Meddie.PeopleFixtures
  import Meddie.SpacesFixtures

  describe "list_people/1" do
    test "returns people scoped to the given space" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope)

      assert [%Person{id: id}] = People.list_people(scope)
      assert id == person.id
    end

    test "does not return people from other spaces" do
      %{scope: scope1} = user_with_space_fixture()
      %{scope: scope2} = user_with_space_fixture()

      person_fixture(scope1)

      assert People.list_people(scope2) == []
    end

    test "returns people ordered by position then name" do
      %{scope: scope} = user_with_space_fixture()
      person_fixture(scope, %{"name" => "Zofia"})
      person_fixture(scope, %{"name" => "Anna"})

      # Same position (auto-incremented 0, 1) — ordered by creation
      people = People.list_people(scope)
      names = Enum.map(people, & &1.name)
      assert names == ["Zofia", "Anna"]

      # After reorder, position takes priority
      People.reorder_people(scope, [List.last(people).id, List.first(people).id])
      names = scope |> People.list_people() |> Enum.map(& &1.name)
      assert names == ["Anna", "Zofia"]
    end
  end

  describe "get_person!/2" do
    test "returns the person in the given space" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope)

      assert %Person{id: id} = People.get_person!(scope, person.id)
      assert id == person.id
    end

    test "raises for a person in another space" do
      %{scope: scope1} = user_with_space_fixture()
      %{scope: scope2} = user_with_space_fixture()

      person = person_fixture(scope1)

      assert_raise Ecto.NoResultsError, fn ->
        People.get_person!(scope2, person.id)
      end
    end
  end

  describe "create_person/2" do
    test "creates a person with valid attributes" do
      %{scope: scope} = user_with_space_fixture()
      attrs = valid_person_attributes(%{"name" => "Jan", "sex" => "male"})

      assert {:ok, %Person{} = person} = People.create_person(scope, attrs)
      assert person.name == "Jan"
      assert person.sex == "male"
      assert person.space_id == scope.space.id
      assert is_nil(person.user_id)
    end

    test "returns error with invalid attributes" do
      %{scope: scope} = user_with_space_fixture()

      assert {:error, changeset} = People.create_person(scope, %{"name" => "", "sex" => ""})
      assert errors_on(changeset).name
      assert errors_on(changeset).sex
    end

    test "returns error with invalid sex value" do
      %{scope: scope} = user_with_space_fixture()

      assert {:error, changeset} =
               People.create_person(scope, %{"name" => "Jan", "sex" => "other"})

      assert errors_on(changeset).sex
    end

    test "links person to user when user_id is provided" do
      %{scope: scope} = user_with_space_fixture()
      attrs = valid_person_attributes(%{"user_id" => scope.user.id})

      assert {:ok, %Person{} = person} = People.create_person(scope, attrs)
      assert person.user_id == scope.user.id
    end

    test "does not link person to user when user_id is absent" do
      %{scope: scope} = user_with_space_fixture()
      attrs = valid_person_attributes()

      assert {:ok, %Person{} = person} = People.create_person(scope, attrs)
      assert is_nil(person.user_id)
    end

    test "returns error when user is already linked to another person in same space" do
      %{scope: scope} = user_with_space_fixture()
      person_fixture(scope, %{"user_id" => scope.user.id})

      assert {:error, changeset} =
               People.create_person(
                 scope,
                 valid_person_attributes(%{"user_id" => scope.user.id})
               )

      assert errors_on(changeset).user_id
    end
  end

  describe "update_person/3" do
    test "updates a person with valid attributes" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope)

      assert {:ok, updated} = People.update_person(scope, person, %{"name" => "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "returns error with invalid attributes" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope)

      assert {:error, changeset} = People.update_person(scope, person, %{"name" => ""})
      assert errors_on(changeset).name
    end

    test "links user when user_id is provided" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope)

      assert {:ok, updated} =
               People.update_person(scope, person, %{"user_id" => scope.user.id})

      assert updated.user_id == scope.user.id
    end

    test "unlinks user when user_id is empty" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope, %{"user_id" => scope.user.id})

      assert {:ok, updated} = People.update_person(scope, person, %{"user_id" => ""})
      assert is_nil(updated.user_id)
    end

    test "updates markdown fields" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope)

      attrs = %{
        "health_notes" => "Diabetes type 2",
        "supplements" => "Vitamin D 2000 IU",
        "medications" => "Metformin 500mg"
      }

      assert {:ok, updated} = People.update_person(scope, person, attrs)
      assert updated.health_notes == "Diabetes type 2"
      assert updated.supplements == "Vitamin D 2000 IU"
      assert updated.medications == "Metformin 500mg"
    end
  end

  describe "delete_person/2" do
    test "deletes the person" do
      %{scope: scope} = user_with_space_fixture()
      person = person_fixture(scope)

      assert {:ok, %Person{}} = People.delete_person(scope, person)

      assert_raise Ecto.NoResultsError, fn ->
        People.get_person!(scope, person.id)
      end
    end
  end

  describe "reorder_people/2" do
    test "updates positions based on ordered ids" do
      %{scope: scope} = user_with_space_fixture()
      p1 = person_fixture(scope, %{"name" => "First"})
      p2 = person_fixture(scope, %{"name" => "Second"})
      p3 = person_fixture(scope, %{"name" => "Third"})

      # Reverse the order
      People.reorder_people(scope, [p3.id, p1.id, p2.id])

      names = scope |> People.list_people() |> Enum.map(& &1.name)
      assert names == ["Third", "First", "Second"]
    end

    test "new people get position at the end" do
      %{scope: scope} = user_with_space_fixture()
      {:ok, p1} = People.create_person(scope, valid_person_attributes(%{"name" => "First"}))
      {:ok, p2} = People.create_person(scope, valid_person_attributes(%{"name" => "Second"}))

      assert p1.position == 0
      assert p2.position == 1
    end
  end

  describe "change_person/2" do
    test "returns a changeset" do
      changeset = People.change_person(%Person{})
      assert %Ecto.Changeset{} = changeset
    end
  end
end
