defmodule Meddie.InvitationsTest do
  use Meddie.DataCase, async: true

  alias Meddie.Invitations
  alias Meddie.Invitations.Invitation
  alias Meddie.Accounts.Scope
  alias Meddie.Spaces

  import Meddie.AccountsFixtures
  import Meddie.SpacesFixtures
  import Meddie.InvitationsFixtures
  import Swoosh.TestAssertions

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

    test "re-inviting expires the old invitation and creates a new one" do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, old} = Invitations.create_platform_invitation(scope, "dup@example.com")
      {:ok, new} = Invitations.create_platform_invitation(scope, "dup@example.com")

      assert new.id != old.id
      assert new.token != old.token

      # Old invitation is now expired
      assert is_nil(Invitations.get_valid_invitation_by_token(old.token))
      # New invitation is valid
      assert Invitations.get_valid_invitation_by_token(new.token)
    end

    test "sends an invitation email" do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, _invitation} = Invitations.create_platform_invitation(scope, "email-test@example.com")

      assert_email_sent(to: "email-test@example.com", subject: "Meddie — Zaproszenie")
    end
  end

  describe "create_space_invitation/3" do
    test "creates invitation for new user" do
      %{scope: scope, space: space} = user_with_space_fixture()

      assert {:ok, %Invitation{} = invitation} =
               Invitations.create_space_invitation(scope, "new@example.com")

      assert invitation.email == "new@example.com"
      assert invitation.space_id == space.id
      assert invitation.role == "member"
      assert is_nil(invitation.accepted_at)
    end

    test "creates invitation with admin role" do
      %{scope: scope} = user_with_space_fixture()

      assert {:ok, invitation} =
               Invitations.create_space_invitation(scope, "admin-invite@example.com", "admin")

      assert invitation.role == "admin"
    end

    test "creates membership immediately for existing user with specified role" do
      %{scope: scope, space: space} = user_with_space_fixture()
      existing_user = user_fixture()

      {:ok, invitation} = Invitations.create_space_invitation(scope, existing_user.email, "admin")

      assert invitation.accepted_at != nil
      assert invitation.role == "admin"
      membership = Spaces.get_membership(existing_user, space)
      assert membership != nil
      assert membership.role == "admin"
    end

    test "creates membership immediately for existing user with default member role" do
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

    test "re-inviting expires the old space invitation and creates a new one" do
      %{scope: scope} = user_with_space_fixture()

      {:ok, old} = Invitations.create_space_invitation(scope, "dup@example.com")
      {:ok, new} = Invitations.create_space_invitation(scope, "dup@example.com")

      assert new.id != old.id
      assert is_nil(Invitations.get_valid_invitation_by_token(old.token))
      assert Invitations.get_valid_invitation_by_token(new.token)
    end

    test "sends an invitation email for new user" do
      %{scope: scope} = user_with_space_fixture()

      {:ok, _} = Invitations.create_space_invitation(scope, "space-email@example.com")

      assert_email_sent(to: "space-email@example.com", subject: "Meddie — Zaproszenie")
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

    test "marks space invitation as accepted and creates membership with invitation role" do
      %{scope: scope, space: space} = user_with_space_fixture()
      {:ok, invitation} = Invitations.create_space_invitation(scope, "role-test@example.com", "admin")
      new_user = user_fixture()

      assert {:ok, %{invitation: accepted, membership: membership}} =
               Invitations.accept_invitation(invitation, new_user)

      assert accepted.accepted_at != nil
      assert membership.space_id == space.id
      assert membership.user_id == new_user.id
      assert membership.role == "admin"
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

  describe "resend_invitation/1" do
    test "resends email for a pending invitation" do
      user = user_fixture()
      invitation = platform_invitation_fixture(user, "resend@example.com")

      assert {:ok, _} = Invitations.resend_invitation(invitation)

      # One from creation + one from resend
      assert_email_sent(to: "resend@example.com", subject: "Meddie — Zaproszenie")
    end

    test "returns error for expired invitation" do
      user = user_fixture()
      scope = Scope.for_user(user)
      {:ok, invitation} = Invitations.create_platform_invitation(scope, "expired-resend@example.com")

      expired_at = DateTime.add(DateTime.utc_now(:second), -1, :day)

      Repo.update_all(
        from(i in Invitation, where: i.id == ^invitation.id),
        set: [expires_at: expired_at]
      )

      invitation = Repo.get!(Invitation, invitation.id)
      assert {:error, :invalid} = Invitations.resend_invitation(invitation)
    end

    test "returns error for accepted invitation" do
      user = user_fixture()
      invitation = platform_invitation_fixture(user, "accepted-resend@example.com")
      new_user = user_fixture()
      {:ok, _} = Invitations.accept_invitation(invitation, new_user)

      accepted = Repo.get!(Invitation, invitation.id)
      assert {:error, :invalid} = Invitations.resend_invitation(accepted)
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

  describe "list_pending_space_invitations/1" do
    test "returns only pending space invitations" do
      %{scope: scope} = user_with_space_fixture()
      _pending = space_invitation_fixture(scope, "pending-space@example.com")

      # Create and accept one
      accepted_inv = space_invitation_fixture(scope, "accepted-space@example.com")
      accepted_user = user_fixture()
      {:ok, _} = Invitations.accept_invitation(accepted_inv, accepted_user)

      pending = Invitations.list_pending_space_invitations(scope)
      assert length(pending) == 1
      assert hd(pending).email == "pending-space@example.com"
    end

    test "does not return expired invitations" do
      %{scope: scope} = user_with_space_fixture()
      {:ok, invitation} = Invitations.create_space_invitation(scope, "exp-space@example.com")

      expired_at = DateTime.add(DateTime.utc_now(:second), -1, :day)

      Repo.update_all(
        from(i in Invitation, where: i.id == ^invitation.id),
        set: [expires_at: expired_at]
      )

      assert Invitations.list_pending_space_invitations(scope) == []
    end
  end

  describe "delete_invitation/1" do
    test "deletes an invitation" do
      user = user_fixture()
      invitation = platform_invitation_fixture(user, "delete@example.com")

      assert {:ok, _} = Invitations.delete_invitation(invitation)
      assert is_nil(Repo.get(Invitation, invitation.id))
    end
  end
end
