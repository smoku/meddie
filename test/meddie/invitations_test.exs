defmodule Meddie.InvitationsTest do
  use Meddie.DataCase, async: true

  alias Meddie.Invitations
  alias Meddie.Invitations.Invitation
  alias Meddie.Accounts.Scope
  alias Meddie.Spaces

  import Meddie.AccountsFixtures
  import Meddie.SpacesFixtures
  import Meddie.InvitationsFixtures

  describe "create_platform_invitation/2" do
    test "creates an invitation with no space" do
      user = user_fixture()
      scope = Scope.for_user(user)

      assert {:ok, %Invitation{} = invitation} =
               Invitations.create_platform_invitation(scope, "new@example.com")

      assert invitation.email == "new@example.com"
      assert is_nil(invitation.space_id)
      assert invitation.invited_by_id == user.id
      assert invitation.token != nil
      assert invitation.expires_at != nil
      assert is_nil(invitation.accepted_at)
    end

    test "normalizes email to lowercase" do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, invitation} = Invitations.create_platform_invitation(scope, "TEST@Example.COM")
      assert invitation.email == "test@example.com"
    end

    test "prevents duplicate pending invitations" do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, _} = Invitations.create_platform_invitation(scope, "dup@example.com")

      assert {:error, changeset} =
               Invitations.create_platform_invitation(scope, "dup@example.com")

      assert "an invitation has already been sent to this email" in errors_on(changeset).email
    end

    test "allows re-inviting after previous invitation was accepted" do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, invitation} = Invitations.create_platform_invitation(scope, "reuse@example.com")
      new_user = user_fixture(%{email: "reuse@example.com"})
      {:ok, _} = Invitations.accept_invitation(invitation, new_user)

      assert {:ok, _} = Invitations.create_platform_invitation(scope, "reuse@example.com")
    end
  end

  describe "create_space_invitation/2" do
    test "creates invitation for new user" do
      %{scope: scope, space: space} = user_with_space_fixture()

      assert {:ok, %Invitation{} = invitation} =
               Invitations.create_space_invitation(scope, "new@example.com")

      assert invitation.email == "new@example.com"
      assert invitation.space_id == space.id
      assert is_nil(invitation.accepted_at)
    end

    test "creates membership immediately for existing user" do
      %{scope: scope, space: space} = user_with_space_fixture()
      existing_user = user_fixture()

      {:ok, invitation} = Invitations.create_space_invitation(scope, existing_user.email)

      assert invitation.accepted_at != nil
      membership = Spaces.get_membership(existing_user, space)
      assert membership != nil
      assert membership.role == "member"
    end

    test "returns error when user is already a member" do
      %{user: user, scope: scope} = user_with_space_fixture()

      assert {:error, :already_member} =
               Invitations.create_space_invitation(scope, user.email)
    end

    test "prevents duplicate pending space invitations" do
      %{scope: scope} = user_with_space_fixture()

      {:ok, _} = Invitations.create_space_invitation(scope, "dup@example.com")
      assert {:error, changeset} = Invitations.create_space_invitation(scope, "dup@example.com")
      assert "an invitation has already been sent to this email" in errors_on(changeset).email
    end
  end

  describe "get_valid_invitation_by_token/1" do
    test "returns invitation for valid token" do
      user = user_fixture()
      invitation = platform_invitation_fixture(user)

      found = Invitations.get_valid_invitation_by_token(invitation.token)
      assert found.id == invitation.id
    end

    test "returns nil for unknown token" do
      assert is_nil(Invitations.get_valid_invitation_by_token("nonexistent"))
    end

    test "returns nil for expired invitation" do
      user = user_fixture()
      scope = Scope.for_user(user)

      # Create invitation then manually expire it
      {:ok, invitation} = Invitations.create_platform_invitation(scope, "exp@example.com")

      expired_at = DateTime.add(DateTime.utc_now(:second), -1, :day)

      Repo.update_all(
        from(i in Invitation, where: i.id == ^invitation.id),
        set: [expires_at: expired_at]
      )

      assert is_nil(Invitations.get_valid_invitation_by_token(invitation.token))
    end

    test "returns nil for accepted invitation" do
      user = user_fixture()
      invitation = platform_invitation_fixture(user)
      new_user = user_fixture()
      {:ok, _} = Invitations.accept_invitation(invitation, new_user)

      assert is_nil(Invitations.get_valid_invitation_by_token(invitation.token))
    end
  end

  describe "accept_invitation/2" do
    test "marks platform invitation as accepted" do
      admin = user_fixture()
      invitation = platform_invitation_fixture(admin)
      new_user = user_fixture()

      assert {:ok, %{invitation: accepted}} = Invitations.accept_invitation(invitation, new_user)
      assert accepted.accepted_at != nil
    end

    test "marks space invitation as accepted and creates membership" do
      %{scope: scope, space: space} = user_with_space_fixture()
      invitation = space_invitation_fixture(scope)
      new_user = user_fixture()

      assert {:ok, %{invitation: accepted, membership: membership}} =
               Invitations.accept_invitation(invitation, new_user)

      assert accepted.accepted_at != nil
      assert membership.space_id == space.id
      assert membership.user_id == new_user.id
      assert membership.role == "member"
    end
  end

  describe "list_pending_platform_invitations/0" do
    test "returns only pending platform invitations" do
      admin = user_fixture()
      _pending = platform_invitation_fixture(admin, "pending@example.com")

      # Create and accept one
      accepted_inv = platform_invitation_fixture(admin, "accepted@example.com")
      accepted_user = user_fixture()
      {:ok, _} = Invitations.accept_invitation(accepted_inv, accepted_user)

      pending = Invitations.list_pending_platform_invitations()
      assert length(pending) == 1
      assert hd(pending).email == "pending@example.com"
    end
  end

  describe "list_space_invitations/1" do
    test "returns invitations for a space" do
      %{scope: scope} = user_with_space_fixture()
      _inv = space_invitation_fixture(scope, "space-invite@example.com")

      invitations = Invitations.list_space_invitations(scope)
      assert length(invitations) == 1
      assert hd(invitations).email == "space-invite@example.com"
    end

    test "does not return invitations from other spaces" do
      %{scope: scope1} = user_with_space_fixture()
      %{scope: scope2} = user_with_space_fixture()

      _inv1 = space_invitation_fixture(scope1, "s1@example.com")
      _inv2 = space_invitation_fixture(scope2, "s2@example.com")

      invitations = Invitations.list_space_invitations(scope1)
      assert length(invitations) == 1
      assert hd(invitations).email == "s1@example.com"
    end
  end
end
