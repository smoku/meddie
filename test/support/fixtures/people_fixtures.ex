defmodule Meddie.PeopleFixtures do
  @moduledoc """
  Test helpers for creating People.
  """

  alias Meddie.People

  def valid_person_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => "Test Person #{System.unique_integer([:positive])}",
      "sex" => "female"
    })
  end

  def person_fixture(scope, attrs \\ %{}) do
    {:ok, person} = People.create_person(scope, valid_person_attributes(attrs))
    person
  end
end
