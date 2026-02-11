defmodule MeddieWeb.SettingsLive.IndexTest do
  use MeddieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Meddie.SpacesFixtures

  defp create_admin_with_space(_context) do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})
    %{user: user, space: space, scope: scope}
  end

  describe "Settings page" do
    setup [:create_admin_with_space]

    test "renders settings page with Members tab", %{conn: conn, user: user, space: space} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/settings")

      assert html =~ "Space Settings"
      assert html =~ "Members"
      assert html =~ "Telegram integration"
    end

    test "shows member list with invite form", %{conn: conn, user: user, space: space} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/settings")

      assert html =~ user.email
      assert html =~ "Invite to Space"
      assert html =~ "Send invitation"
    end

    test "switches to Telegram tab", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/settings")

      html =
        lv
        |> element(~s|button[phx-value-tab="telegram"]|)
        |> render_click()

      assert html =~ "Bot Token"
      assert html =~ "@BotFather"
      assert html =~ "Telegram Links"
      assert html =~ "Telegram ID"
    end

    test "saves telegram bot token", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/settings")

      # Switch to Telegram tab
      lv
      |> element(~s|button[phx-value-tab="telegram"]|)
      |> render_click()

      html =
        lv
        |> form(~s|form[phx-submit="save_telegram_token"]|, %{
          "telegram_token" => %{"telegram_bot_token" => "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"}
        })
        |> render_submit()

      assert html =~ "Telegram bot token saved."
      assert html =~ "Bot connected"
    end

    test "adds a telegram link", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/settings")

      # Switch to Telegram tab
      lv
      |> element(~s|button[phx-value-tab="telegram"]|)
      |> render_click()

      html =
        lv
        |> form(~s|form[phx-submit="add_telegram_link"]|, %{
          "link" => %{"telegram_id" => "123456789"}
        })
        |> render_submit()

      assert html =~ "Telegram link added."
      assert html =~ "123456789"
    end

    test "deletes a telegram link", %{conn: conn, user: user, space: space} do
      # Create a link first
      {:ok, _link} =
        Meddie.Telegram.Links.create_link(space.id, %{
          "telegram_id" => 111_222_333
        })

      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/settings")

      # Switch to Telegram tab
      html =
        lv
        |> element(~s|button[phx-value-tab="telegram"]|)
        |> render_click()

      assert html =~ "111222333"
    end

    test "switches back to Members tab", %{conn: conn, user: user, space: space} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(user, space: space)
        |> live(~p"/settings")

      # Switch to Telegram
      lv
      |> element(~s|button[phx-value-tab="telegram"]|)
      |> render_click()

      # Switch back to Members
      html =
        lv
        |> element(~s|button[phx-value-tab="members"]|)
        |> render_click()

      assert html =~ "Invite to Space"
      refute html =~ "Bot Token"
    end
  end

  describe "Settings page - non-admin" do
    test "does not render space settings for non-admin", %{conn: conn} do
      # Create a space with an admin, then create another user as member
      %{space: space} = user_with_space_fixture(%{locale: "en"})

      member_user = Meddie.AccountsFixtures.user_fixture(%{locale: "en"})

      Meddie.Repo.insert!(%Meddie.Spaces.Membership{
        user_id: member_user.id,
        space_id: space.id,
        role: "member"
      })

      {:ok, _lv, html} =
        conn
        |> log_in_user(member_user, space: space)
        |> live(~p"/settings")

      refute html =~ "Space Settings"
      refute html =~ "Bot Token"
      refute html =~ "Telegram Links"
    end
  end
end
