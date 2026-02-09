defmodule Meddie.Spaces do
  @moduledoc """
  The Spaces context. Manages Spaces and Memberships.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts.Scope
  alias Meddie.Spaces.{Space, Membership}

  @doc """
  Creates a space and adds the user as an admin member.
  """
  def create_space(%Scope{user: user}, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:space, Space.changeset(%Space{}, attrs))
    |> Ecto.Multi.insert(:membership, fn %{space: space} ->
      Membership.changeset(%Membership{}, %{
        user_id: user.id,
        space_id: space.id,
        role: "admin"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{space: space}} -> {:ok, space}
      {:error, :space, changeset, _} -> {:error, changeset}
      {:error, :membership, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Returns all spaces the given user belongs to.
  """
  def list_user_spaces(user) do
    from(s in Space,
      join: m in Membership,
      on: m.space_id == s.id,
      where: m.user_id == ^user.id,
      order_by: [asc: s.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single space.
  """
  def get_space!(id), do: Repo.get!(Space, id)

  @doc """
  Gets a space if the user is a member.
  """
  def get_space_for_user(user, space_id) do
    from(s in Space,
      join: m in Membership,
      on: m.space_id == s.id,
      where: s.id == ^space_id and m.user_id == ^user.id
    )
    |> Repo.one()
  end

  @doc """
  Gets the membership for a user in a space.
  """
  def get_membership(user, space) do
    Repo.get_by(Membership, user_id: user.id, space_id: space.id)
  end

  @doc """
  Returns the user's role in a space.
  """
  def get_user_role(user, space) do
    case get_membership(user, space) do
      %Membership{role: role} -> role
      nil -> nil
    end
  end

  @doc """
  Lists all members of a space with user preloaded.
  """
  def list_space_members(%Scope{space: space}) do
    from(m in Membership,
      where: m.space_id == ^space.id,
      preload: [:user],
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Removes a member from a space. Prevents removing the last admin.
  """
  def remove_member(%Scope{space: space}, membership_id) do
    membership = Repo.get_by!(Membership, id: membership_id, space_id: space.id)

    if membership.role == "admin" do
      admin_count =
        from(m in Membership,
          where: m.space_id == ^space.id and m.role == "admin"
        )
        |> Repo.aggregate(:count)

      if admin_count <= 1 do
        {:error, :last_admin}
      else
        Repo.delete(membership)
      end
    else
      Repo.delete(membership)
    end
  end

  @doc """
  Updates a space name.
  """
  def update_space(%Scope{space: space}, attrs) do
    space
    |> Space.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking space changes.
  """
  def change_space(%Space{} = space, attrs \\ %{}) do
    Space.changeset(space, attrs)
  end
end
