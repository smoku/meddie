defmodule MeddieWeb.UserLive.RegistrationTest do
  use MeddieWeb.ConnCase, async: true

  describe "Registration page" do
    test "public /users/register route does not exist", %{conn: conn} do
      conn = get(conn, "/users/register")
      assert conn.status == 404
    end
  end
end
