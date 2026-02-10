defmodule MeddieWeb.SettingsLive.Index do
  use MeddieWeb, :live_view

  alias Meddie.Spaces
  alias Meddie.Invitations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      page_title={gettext("Settings")}
    >
      <div class="max-w-4xl space-y-8">
        <%!-- Space Settings (admin only) --%>
        <section :if={@is_admin}>
          <h2 class="text-xl font-bold mb-4">{gettext("Space Settings")}</h2>

          <%!-- Members --%>
          <div class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h3 class="card-title text-base">{gettext("Members")}</h3>
              <div class="overflow-x-auto">
                <table class="table">
                  <thead>
                    <tr>
                      <th>{gettext("Name")}</th>
                      <th>{gettext("Email")}</th>
                      <th>{gettext("Role")}</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={member <- @members}>
                      <td>{member.user.name || "—"}</td>
                      <td>{member.user.email}</td>
                      <td>
                        <span class={[
                          "badge badge-sm",
                          member.role == "admin" && "badge-primary",
                          member.role == "member" && "badge-ghost"
                        ]}>
                          {display_role(member.role)}
                        </span>
                      </td>
                      <td>
                        <button
                          :if={member.user_id != @current_scope.user.id}
                          phx-click="remove_member"
                          phx-value-id={member.id}
                          data-confirm={gettext("Are you sure you want to remove this member?")}
                          class="btn btn-ghost btn-xs text-error"
                        >
                          {gettext("Remove")}
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <%!-- Invite form --%>
              <div class="mt-4">
                <h4 class="font-semibold text-sm mb-2">{gettext("Invite to Space")}</h4>
                <.form for={@invite_form} phx-submit="invite_to_space" class="flex gap-2">
                  <.input
                    field={@invite_form[:email]}
                    type="email"
                    placeholder="email@example.com"
                    class="input input-bordered input-sm flex-1"
                    required
                  />
                  <button type="submit" class="btn btn-primary btn-sm">{gettext("Send invitation")}</button>
                </.form>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.sidebar>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    role = Spaces.get_user_role(scope.user, scope.space)
    is_admin = role == "admin"

    members = if is_admin, do: Spaces.list_space_members(scope), else: []

    {:ok,
     socket
     |> assign(page_title: gettext("Settings"), is_admin: is_admin, members: members)
     |> assign(invite_form: to_form(%{"email" => ""}, as: "invite"))}
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    case Spaces.remove_member(socket.assigns.current_scope, id) do
      {:ok, _} ->
        members = Spaces.list_space_members(socket.assigns.current_scope)
        {:noreply, socket |> put_flash(:info, gettext("Member removed.")) |> assign(members: members)}

      {:error, :last_admin} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You are the only admin. Transfer admin role to another member before leaving.")
         )}
    end
  end

  def handle_event("invite_to_space", %{"invite" => %{"email" => email}}, socket) do
    case Invitations.create_space_invitation(socket.assigns.current_scope, email) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Invitation sent to %{email}.", email: email))
         |> assign(invite_form: to_form(%{"email" => ""}, as: "invite"))}

      {:error, :already_member} ->
        {:noreply, put_flash(socket, :error, gettext("This user is already a member of this space."))}

      {:error, changeset} ->
        message =
          case changeset.errors[:email] do
            {msg, _} -> msg
            _ -> gettext("Could not send invitation.")
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp display_role("admin"), do: gettext("admin")
  defp display_role("member"), do: gettext("member")
  defp display_role(role), do: role
end
