defmodule MeddieWeb.PageControllerTest do
  use MeddieWeb.ConnCase

  test "GET / redirects to /ask-meddie", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/ask-meddie"
  end
end
