defmodule MeddieWeb.UserLive.SettingsTest do
  use MeddieWeb.ConnCase, async: true

  alias Meddie.Accounts
  import Phoenix.LiveViewTest
  import Meddie.AccountsFixtures
  import Meddie.SpacesFixtures

  defp create_user_with_space(_context) do
    %{user: user, space: space} = user_with_space_fixture(%{locale: "en"})
    %{user: user, space: space}
  end

  describe "Settings page" do
    setup [:create_user_with_space]

    test "renders settings page", %{conn: conn, user: user, space: space} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      assert html =~ "Account Settings"
      assert html =~ "Profile"
      assert html =~ "Save"
      assert html =~ "Change email"
      assert html =~ "Change password"
      assert html =~ "Language"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update profile form" do
    setup [:create_user_with_space]

    test "updates name and locale", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      result =
        lv
        |> form("#profile_form", %{"user" => %{"name" => "New Name", "locale" => "en"}})
        |> render_submit()

      assert result =~ "Profile updated successfully."
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.name == "New Name"
      assert updated_user.locale == "en"
    end

    test "renders errors with invalid data", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      result =
        lv
        |> form("#profile_form", %{"user" => %{"name" => ""}})
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "update email form" do
    setup [:create_user_with_space]

    test "updates the user email", %{conn: conn, user: user, space: space} do
      new_email = unique_user_email()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change email"
      assert result =~ "did not change"
    end
  end

  describe "update password form" do
    setup [:create_user_with_space]

    test "updates the user password", %{conn: conn, user: user, space: space} do
      new_password = valid_user_password()
      logged_in_conn = log_in_user(conn, user, space: space)

      {:ok, lv, _html} = live(logged_in_conn, ~p"/users/settings")

      form =
        form(lv, "#password_form", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, logged_in_conn)

      assert redirected_to(new_password_conn) == ~p"/users/settings"

      assert get_session(new_password_conn, :user_token) !=
               get_session(logged_in_conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings")

      result =
        lv
        |> form("#password_form", %{
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "confirm email" do
    setup [:create_user_with_space]

    setup %{user: user} do
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the user email once", %{
      conn: conn,
      user: user,
      space: space,
      token: token,
      email: email
    } do
      {:error, redirect} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user, space: space} do
      {:error, redirect} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/users/settings/confirm-email/oops")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
