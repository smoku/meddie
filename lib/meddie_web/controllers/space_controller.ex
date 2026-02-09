defmodule MeddieWeb.SpaceController do
  use MeddieWeb, :controller

  alias Meddie.Spaces
  alias MeddieWeb.UserAuth

  def switch(conn, %{"id" => space_id}) do
    user = conn.assigns.current_scope.user

    if Spaces.get_space_for_user(user, space_id) do
      conn
      |> UserAuth.put_space_in_session(space_id)
      |> redirect(to: ~p"/people")
    else
      conn
      |> put_flash(:error, "Space not found.")
      |> redirect(to: ~p"/people")
    end
  end
end
