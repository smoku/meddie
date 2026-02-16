defmodule MeddieWeb.PageController do
  use MeddieWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/ask-meddie")
  end
end
