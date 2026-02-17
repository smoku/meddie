defmodule Meddie.People do
  @moduledoc """
  The People context. Manages health profiles within a Space.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts.Scope
  alias Meddie.People.Person

  @topic_prefix "space_people:"

  @doc """
  Subscribes to people changes for the given space.
  """
  def subscribe_people(space_id) do
    Phoenix.PubSub.subscribe(Meddie.PubSub, @topic_prefix <> space_id)
  end

  defp broadcast_people_change(space_id) do
    Phoenix.PubSub.broadcast(Meddie.PubSub, @topic_prefix <> space_id, :people_changed)
  end

  @doc """
  Returns the list of people for the given scope's space, ordered by position then name.
  """
  def list_people(%Scope{space: space}) do
    from(p in Person, where: p.space_id == ^space.id, order_by: [asc: p.position, asc: p.name])
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
  Reorders people in the given space by updating their positions.
  `ordered_ids` is a list of person IDs in the desired order.
  """
  def reorder_people(%Scope{space: space}, ordered_ids) when is_list(ordered_ids) do
    Repo.transaction(fn ->
      Enum.with_index(ordered_ids, fn id, index ->
        from(p in Person, where: p.id == ^id and p.space_id == ^space.id)
        |> Repo.update_all(set: [position: index])
      end)
    end)

    broadcast_people_change(space.id)
    :ok
  end

  @doc """
  Creates a person in the given scope's space.

  If `"user_id"` is present in attrs, links the person to that user.
  New people are placed at the end of the list.
  """
  def create_person(%Scope{space: space}, attrs) do
    {user_id, attrs} = Map.pop(attrs, "user_id")

    next_position =
      from(p in Person, where: p.space_id == ^space.id, select: coalesce(max(p.position), -1))
      |> Repo.one()
      |> Kernel.+(1)

    result =
      %Person{space_id: space.id, position: next_position}
      |> maybe_set_user_id(user_id)
      |> Person.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, _person} -> broadcast_people_change(space.id)
      _ -> :ok
    end

    result
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
    result = Repo.delete(person)

    case result do
      {:ok, _} -> broadcast_people_change(person.space_id)
      _ -> :ok
    end

    result
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
