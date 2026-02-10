defmodule MeddieWeb.InvitationControllerTest do
  use MeddieWeb.ConnCase, async: true

  import Ecto.Query
  import Meddie.AccountsFixtures
  import Meddie.SpacesFixtures
  import Meddie.InvitationsFixtures

  alias Meddie.Accounts
  alias Meddie.Spaces

  describe "GET /invitations/:token - show" do
    test "renders registration form for valid token and new user", %{conn: conn} do
      admin = user_fixture()
      invitation = platform_invitation_fixture(admin, "new@example.com")

      conn = get(conn, ~p"/invitations/#{invitation.token}")
      response = html_response(conn, 200)
      assert response =~ "new@example.com"
      assert response =~ "Utwórz konto"
    end

    test "redirects to login for valid token and existing user", %{conn: conn} do
      admin = user_fixture()
      existing_user = user_fixture(%{email: "existing@example.com"})
      invitation = platform_invitation_fixture(admin, existing_user.email)

      conn = get(conn, ~p"/invitations/#{invitation.token}")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "You already have an account"
    end

    test "redirects to login for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/invitations/bad-token")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    end

    test "redirects to login for expired token", %{conn: conn} do
      admin = user_fixture()
      invitation = platform_invitation_fixture(admin, "expired@example.com")

      # Manually expire
      expired_at = DateTime.add(DateTime.utc_now(:second), -1, :day)

      Meddie.Repo.update_all(
        from(i in Meddie.Invitations.Invitation, where: i.id == ^invitation.id),
        set: [expires_at: expired_at]
      )

      conn = get(conn, ~p"/invitations/#{invitation.token}")
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    end
  end

  describe "POST /invitations/:token/accept" do
    test "registers user and accepts platform invitation", %{conn: conn} do
      admin = user_fixture()
      invitation = platform_invitation_fixture(admin, "newuser@example.com")

      conn =
        post(conn, ~p"/invitations/#{invitation.token}/accept", %{
          "user" => %{
            "name" => "New User",
            "password" => "validpassword123",
            "password_confirmation" => "validpassword123"
          }
        })

      # Platform invite redirects to /spaces/new
      assert redirected_to(conn) == ~p"/spaces/new"
      assert get_session(conn, :user_token)

      # User was created and confirmed
      user = Accounts.get_user_by_email("newuser@example.com")
      assert user.name == "New User"
      assert user.confirmed_at != nil
    end

    test "registers user and accepts space invitation", %{conn: conn} do
      %{scope: scope, space: space} = user_with_space_fixture()
      invitation = space_invitation_fixture(scope, "spaceuser@example.com")

      conn =
        post(conn, ~p"/invitations/#{invitation.token}/accept", %{
          "user" => %{
            "name" => "Space User",
            "password" => "validpassword123",
            "password_confirmation" => "validpassword123"
          }
        })

      # Space invite redirects to /people
      assert redirected_to(conn) == ~p"/people"
      assert get_session(conn, :user_token)

      # User is a member of the space
      user = Accounts.get_user_by_email("spaceuser@example.com")
      membership = Spaces.get_membership(user, space)
      assert membership != nil
      assert membership.role == "member"
    end

    test "re-renders form with errors for invalid data", %{conn: conn} do
      admin = user_fixture()
      invitation = platform_invitation_fixture(admin, "err@example.com")

      conn =
        post(conn, ~p"/invitations/#{invitation.token}/accept", %{
          "user" => %{
            "name" => "",
            "password" => "short",
            "password_confirmation" => "mismatch"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "Utwórz konto"
    end

    test "redirects for invalid token", %{conn: conn} do
      conn =
        post(conn, ~p"/invitations/bad-token/accept", %{
          "user" => %{
            "name" => "Test",
            "password" => "validpassword123",
            "password_confirmation" => "validpassword123"
          }
        })

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    end
  end
end
