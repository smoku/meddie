defmodule MeddieWeb.PlatformLive.Index do
  use MeddieWeb, :live_view

  alias Meddie.Invitations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-2xl mx-auto space-y-8">
        <h1 class="text-2xl font-bold">Platform Admin</h1>

        <%!-- Invite new user --%>
        <section>
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h2 class="card-title text-base">Invite new user</h2>
              <.form for={@invite_form} phx-submit="invite_user" class="flex gap-2">
                <.input
                  field={@invite_form[:email]}
                  type="email"
                  placeholder="email@example.com"
                  required
                />
                <button type="submit" class="btn btn-primary btn-sm">Send invitation</button>
              </.form>
            </div>
          </div>
        </section>

        <%!-- Pending invitations --%>
        <section :if={@pending_invitations != []}>
          <h2 class="text-lg font-semibold mb-2">Pending Invitations</h2>
          <div class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Invited by</th>
                  <th>Expires</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={inv <- @pending_invitations}>
                  <td>{inv.email}</td>
                  <td>{inv.invited_by.name || inv.invited_by.email}</td>
                  <td>{Calendar.strftime(inv.expires_at, "%Y-%m-%d")}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <%!-- All spaces --%>
        <section>
          <h2 class="text-lg font-semibold mb-2">All Spaces</h2>
          <div :if={@spaces == []} class="text-base-content/50 text-sm">
            No spaces yet.
          </div>
          <div :if={@spaces != []} class="overflow-x-auto">
            <table class="table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={space <- @spaces}>
                  <td>{space.name}</td>
                  <td>{Calendar.strftime(space.inserted_at, "%Y-%m-%d")}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <div class="text-center">
          <.link navigate={~p"/people"} class="btn btn-ghost btn-sm">
            &larr; Back to app
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    pending_invitations = Invitations.list_pending_platform_invitations()
    spaces = list_all_spaces()

    {:ok,
     socket
     |> assign(
       page_title: "Platform Admin",
       pending_invitations: pending_invitations,
       spaces: spaces,
       invite_form: to_form(%{"email" => ""}, as: "invite")
     )}
  end

  @impl true
  def handle_event("invite_user", %{"invite" => %{"email" => email}}, socket) do
    case Invitations.create_platform_invitation(socket.assigns.current_scope, email) do
      {:ok, _invitation} ->
        pending_invitations = Invitations.list_pending_platform_invitations()

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}.")
         |> assign(
           pending_invitations: pending_invitations,
           invite_form: to_form(%{"email" => ""}, as: "invite")
         )}

      {:error, changeset} ->
        message =
          case changeset.errors[:email] do
            {msg, _} -> msg
            _ -> "Could not send invitation."
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp list_all_spaces do
    import Ecto.Query
    Meddie.Repo.all(from(s in Meddie.Spaces.Space, order_by: [asc: s.name]))
  end
end
