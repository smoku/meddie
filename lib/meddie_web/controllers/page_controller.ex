defmodule MeddieWeb.PageController do
  use MeddieWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/people")
  end
end
