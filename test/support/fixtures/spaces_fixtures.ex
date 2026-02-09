defmodule Meddie.SpacesFixtures do
  @moduledoc """
  Test helpers for creating Spaces and Memberships.
  """

  alias Meddie.Accounts.Scope
  alias Meddie.Spaces

  def valid_space_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Space #{System.unique_integer([:positive])}"
    })
  end

  @doc """
  Creates a space with the given user as admin.
  Returns the space.
  """
  def space_fixture(user, attrs \\ %{}) do
    scope = Scope.for_user(user)
    {:ok, space} = Spaces.create_space(scope, valid_space_attributes(attrs))
    space
  end

  @doc """
  Creates a user, space, and scope with the space set.
  Returns %{user, space, scope}.
  """
  def user_with_space_fixture(user_attrs \\ %{}) do
    user = Meddie.AccountsFixtures.user_fixture(user_attrs)
    space = space_fixture(user)
    scope = Scope.for_user(user) |> Scope.put_space(space)
    %{user: user, space: space, scope: scope}
  end
end
