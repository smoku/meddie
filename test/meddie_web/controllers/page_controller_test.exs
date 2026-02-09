defmodule MeddieWeb.PageControllerTest do
  use MeddieWeb.ConnCase

  test "GET / redirects to /people", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/people"
  end
end
