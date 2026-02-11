defmodule Meddie.People do
  @moduledoc """
  The People context. Manages health profiles within a Space.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts.Scope
  alias Meddie.People.Person

  @doc """
  Returns the list of people for the given scope's space, ordered by name.
  """
  def list_people(%Scope{space: space}) do
    from(p in Person, where: p.space_id == ^space.id, order_by: [asc: p.name])
    |> Repo.all()
  end

  @doc """
  Gets a single person scoped to the given space.

  Raises `Ecto.NoResultsError` if the Person does not exist in the space.
  """
  def get_person!(%Scope{space: space}, id) do
    Repo.get_by!(Person, id: id, space_id: space.id)
  end

  @doc """
  Gets the person linked to the current user in the current space.
  Returns nil if the user has no linked person.
  """
  def get_linked_person(%Scope{user: user, space: space}) do
    Repo.get_by(Person, user_id: user.id, space_id: space.id)
  end

  @doc """
  Creates a person in the given scope's space.

  If `"user_id"` is present in attrs, links the person to that user.
  """
  def create_person(%Scope{space: space}, attrs) do
    {user_id, attrs} = Map.pop(attrs, "user_id")

    %Person{space_id: space.id}
    |> maybe_set_user_id(user_id)
    |> Person.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a person.

  If `"user_id"` is present in attrs, links the person to that user.
  If `"user_id"` is `""`, removes the user link.
  """
  def update_person(%Scope{}, %Person{} = person, attrs) do
    {user_id, attrs} = Map.pop(attrs, "user_id")

    person
    |> maybe_set_user_id(user_id)
    |> Person.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a person.
  """
  def delete_person(%Scope{}, %Person{} = person) do
    Repo.delete(person)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking person changes.
  """
  def change_person(%Person{} = person, attrs \\ %{}) do
    Person.changeset(person, attrs)
  end

  defp maybe_set_user_id(person_or_changeset, user_id)
       when is_binary(user_id) and user_id != "" do
    Ecto.Changeset.change(person_or_changeset, user_id: user_id)
  end

  defp maybe_set_user_id(person_or_changeset, "") do
    Ecto.Changeset.change(person_or_changeset, user_id: nil)
  end

  defp maybe_set_user_id(person_or_changeset, _nil) do
    person_or_changeset
  end
end
