defmodule Meddie.InvitationsFixtures do
  @moduledoc """
  Test helpers for creating Invitations.
  """

  alias Meddie.Accounts.Scope
  alias Meddie.Invitations

  @doc """
  Creates a platform invitation.
  """
  def platform_invitation_fixture(user, email \\ nil) do
    email = email || "invited#{System.unique_integer([:positive])}@example.com"
    scope = Scope.for_user(user)
    {:ok, invitation} = Invitations.create_platform_invitation(scope, email)
    invitation
  end

  @doc """
  Creates a space invitation for a new (non-existing) email.
  """
  def space_invitation_fixture(scope, email \\ nil) do
    email = email || "invited#{System.unique_integer([:positive])}@example.com"
    {:ok, invitation} = Invitations.create_space_invitation(scope, email)
    invitation
  end
end
