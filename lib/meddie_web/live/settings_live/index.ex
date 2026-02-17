defmodule MeddieWeb.SettingsLive.Index do
  use MeddieWeb, :live_view

  alias Meddie.Spaces
  alias Meddie.Invitations
  alias Meddie.Telegram

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      people={@people}
      page_title={gettext("Settings")}
    >
      <div class="max-w-4xl space-y-8">
        <%!-- Space Settings (admin only) --%>
        <section :if={@is_admin}>
          <h2 class="text-xl font-bold mb-4">{gettext("Space Settings")}</h2>

          <%!-- Tabs --%>
          <div class="flex gap-1 border-b-2 border-base-300/50 mb-6">
            <button
              phx-click="switch_tab"
              phx-value-tab="members"
              class={[
                "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
                if(@tab == "members",
                  do: "border-primary text-primary bg-primary/5 rounded-t-lg",
                  else: "border-transparent text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              {gettext("Members")}
            </button>
            <button
              phx-click="switch_tab"
              phx-value-tab="telegram"
              class={[
                "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
                if(@tab == "telegram",
                  do: "border-primary text-primary bg-primary/5 rounded-t-lg",
                  else: "border-transparent text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              {gettext("Telegram integration")}
            </button>
          </div>

          <%!-- Members tab --%>
          <div :if={@tab == "members"}>
            <div class="card bg-base-100 shadow-elevated border border-base-300/20">
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
                  <.form for={@invite_form} phx-submit="invite_to_space" id={"invite-form-#{@invite_form_id}"} class="flex gap-2 items-center">
                    <input
                      type="email"
                      name={@invite_form[:email].name}
                      value={@invite_form[:email].value}
                      placeholder="email@example.com"
                      class="input input-bordered input-sm w-64"
                      required
                    />
                    <select name="invite[role]" class="select select-bordered select-sm w-auto">
                      <option value="member" selected>{gettext("member")}</option>
                      <option value="admin">{gettext("admin")}</option>
                    </select>
                    <button type="submit" class="btn btn-primary btn-sm">
                      {gettext("Send invitation")}
                    </button>
                  </.form>
                </div>

                <%!-- Pending invitations --%>
                <div :if={@pending_invitations != []} class="mt-6">
                  <h4 class="font-semibold text-sm mb-2">{gettext("Pending Invitations")}</h4>
                  <div class="overflow-x-auto">
                    <table class="table">
                      <thead>
                        <tr>
                          <th>{gettext("Email")}</th>
                          <th>{gettext("Role")}</th>
                          <th>{gettext("Invited by")}</th>
                          <th>{gettext("Expires")}</th>
                          <th></th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={inv <- @pending_invitations}>
                          <td>{inv.email}</td>
                          <td>
                            <span class={[
                              "badge badge-sm",
                              inv.role == "admin" && "badge-primary",
                              inv.role == "member" && "badge-ghost"
                            ]}>
                              {display_role(inv.role)}
                            </span>
                          </td>
                          <td>{inv.invited_by.name || inv.invited_by.email}</td>
                          <td>{Calendar.strftime(inv.expires_at, "%Y-%m-%d")}</td>
                          <td class="flex gap-1">
                            <button
                              phx-click="resend_invitation"
                              phx-value-id={inv.id}
                              class="btn btn-ghost btn-xs"
                            >
                              {gettext("Resend")}
                            </button>
                            <button
                              phx-click="delete_invitation"
                              phx-value-id={inv.id}
                              data-confirm={gettext("Delete this invitation?")}
                              class="btn btn-ghost btn-xs text-error"
                            >
                              {gettext("Delete")}
                            </button>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Telegram tab --%>
          <div :if={@tab == "telegram"} class="space-y-6">
            <%!-- Bot Token --%>
            <div class="card bg-base-100 shadow-elevated border border-base-300/20">
              <div class="card-body">
                <h3 class="card-title text-base">{gettext("Bot Token")}</h3>
                <p class="text-sm text-base-content/60 mb-2">
                  {gettext("Create a bot via @BotFather on Telegram and paste the token here.")}
                </p>
                <div class="space-y-2">
                  <.form for={@telegram_token_form} phx-submit="save_telegram_token" class="flex gap-2 items-center">
                    <input
                      type="text"
                      name={@telegram_token_form[:telegram_bot_token].name}
                      value={@telegram_token_form[:telegram_bot_token].value}
                      placeholder="123456:ABC-DEF..."
                      class="input input-bordered input-sm flex-1 font-mono"
                    />
                    <button type="submit" class="btn btn-primary btn-sm">
                      {gettext("Save")}
                    </button>
                  </.form>
                  <span
                    :if={@current_scope.space.telegram_bot_token && @current_scope.space.telegram_bot_token != ""}
                    class="badge badge-success badge-sm gap-1"
                  >
                    <span class="w-2 h-2 rounded-full bg-success animate-pulse"></span>
                    {gettext("Bot connected")}
                  </span>
                </div>
              </div>
            </div>

            <%!-- Telegram Links --%>
            <div class="card bg-base-100 shadow-elevated border border-base-300/20">
              <div class="card-body">
                <h3 class="card-title text-base">{gettext("Telegram Links")}</h3>
                <p class="text-sm text-base-content/60 mb-2">
                  {gettext("Link Telegram accounts to people or users. Telegram users can find their ID by messaging @userinfobot.")}
                </p>

                <%!-- Existing links --%>
                <div :if={@telegram_links != []} class="overflow-x-auto mb-4">
                  <table class="table">
                    <thead>
                      <tr>
                        <th>{gettext("Telegram ID")}</th>
                        <th>{gettext("Linked Person")}</th>
                        <th>{gettext("Linked User")}</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={link <- @telegram_links}>
                        <td class="font-mono text-sm">{link.telegram_id}</td>
                        <td>
                          <span :if={link.person} class="badge badge-info badge-sm">
                            {link.person.name}
                          </span>
                          <span :if={!link.person} class="text-base-content/40">—</span>
                        </td>
                        <td>
                          <span :if={link.user} class="badge badge-ghost badge-sm">
                            {link.user.name || link.user.email}
                          </span>
                          <span :if={!link.user} class="text-base-content/40">—</span>
                        </td>
                        <td>
                          <button
                            phx-click="delete_telegram_link"
                            phx-value-id={link.id}
                            data-confirm={gettext("Remove this Telegram link?")}
                            class="btn btn-ghost btn-xs text-error"
                          >
                            {gettext("Remove")}
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <p :if={@telegram_links == []} class="text-sm text-base-content/40 mb-4">
                  {gettext("No Telegram links yet.")}
                </p>

                <%!-- Add link form --%>
                <div class="border-t border-base-300/30 pt-4">
                  <h4 class="font-semibold text-sm mb-2">{gettext("Add Telegram Link")}</h4>
                  <.form for={@new_link_form} phx-submit="add_telegram_link" class="flex flex-wrap gap-2 items-end">
                    <div>
                      <label class="label label-text text-xs">{gettext("Telegram ID")}</label>
                      <input
                        type="number"
                        name="link[telegram_id]"
                        placeholder="123456789"
                        class="input input-bordered input-sm w-36 font-mono"
                        required
                      />
                    </div>
                    <div>
                      <label class="label label-text text-xs">{gettext("Person")}</label>
                      <select name="link[person_id]" class="select select-bordered select-sm w-40">
                        <option value="">{gettext("None")}</option>
                        <option :for={person <- @people} value={person.id}>{person.name}</option>
                      </select>
                    </div>
                    <div>
                      <label class="label label-text text-xs">{gettext("User")}</label>
                      <select name="link[user_id]" class="select select-bordered select-sm w-44">
                        <option value="">{gettext("None")}</option>
                        <option :for={member <- @members} value={member.user.id}>
                          {member.user.name || member.user.email}
                        </option>
                      </select>
                    </div>
                    <button type="submit" class="btn btn-primary btn-sm">
                      {gettext("Add")}
                    </button>
                  </.form>
                </div>
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
    pending_invitations = if is_admin, do: Invitations.list_pending_space_invitations(scope), else: []
    telegram_links = if is_admin, do: Telegram.Links.list_links(scope.space.id), else: []

    {:ok,
     socket
     |> assign(
       page_title: gettext("Settings"),
       is_admin: is_admin,
       members: members,
       pending_invitations: pending_invitations,
       telegram_links: telegram_links,
       tab: "members"
     )
     |> assign(invite_form: to_form(%{"email" => ""}, as: "invite"), invite_form_id: 0)
     |> assign_telegram_forms()}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    case Spaces.remove_member(socket.assigns.current_scope, id) do
      {:ok, _} ->
        members = Spaces.list_space_members(socket.assigns.current_scope)

        {:noreply,
         socket |> put_flash(:info, gettext("Member removed.")) |> assign(members: members)}

      {:error, :last_admin} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext(
             "You are the only admin. Transfer admin role to another member before leaving."
           )
         )}
    end
  end

  def handle_event("invite_to_space", %{"invite" => %{"email" => email} = params}, socket) do
    role = Map.get(params, "role", "member")
    scope = socket.assigns.current_scope

    case Invitations.create_space_invitation(scope, email, role) do
      {:ok, _} ->
        pending_invitations = Invitations.list_pending_space_invitations(scope)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Invitation sent to %{email}.", email: email))
         |> assign(
           invite_form: to_form(%{"email" => ""}, as: "invite"),
           invite_form_id: socket.assigns.invite_form_id + 1,
           pending_invitations: pending_invitations
         )}

      {:error, :already_member} ->
        {:noreply,
         put_flash(socket, :error, gettext("This user is already a member of this space."))}

      {:error, changeset} ->
        message =
          case changeset.errors[:email] do
            {msg, _} -> msg
            _ -> gettext("Could not send invitation.")
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("resend_invitation", %{"id" => id}, socket) do
    invitation = Meddie.Repo.get!(Meddie.Invitations.Invitation, id)

    case Invitations.resend_invitation(invitation) do
      {:ok, _} ->
        {:noreply,
         put_flash(socket, :info, gettext("Invitation resent to %{email}.", email: invitation.email))}

      {:error, :invalid} ->
        {:noreply, put_flash(socket, :error, gettext("This invitation is no longer valid."))}
    end
  end

  def handle_event("delete_invitation", %{"id" => id}, socket) do
    invitation = Meddie.Repo.get!(Meddie.Invitations.Invitation, id)

    case Invitations.delete_invitation(invitation) do
      {:ok, _} ->
        pending_invitations =
          Invitations.list_pending_space_invitations(socket.assigns.current_scope)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Invitation deleted."))
         |> assign(pending_invitations: pending_invitations)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not delete invitation."))}
    end
  end

  def handle_event("save_telegram_token", %{"telegram_token" => %{"telegram_bot_token" => token}}, socket) do
    scope = socket.assigns.current_scope
    old_token = scope.space.telegram_bot_token

    case Spaces.update_telegram_token(scope, %{telegram_bot_token: String.trim(token)}) do
      {:ok, updated_space} ->
        updated_scope = %{scope | space: updated_space}

        manage_poller(old_token, updated_space)

        {:noreply,
         socket
         |> assign(current_scope: updated_scope)
         |> assign_telegram_forms()
         |> put_flash(:info, gettext("Telegram bot token saved."))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save bot token."))}
    end
  end

  def handle_event("add_telegram_link", %{"link" => link_params}, socket) do
    space_id = socket.assigns.current_scope.space.id

    attrs = %{
      "telegram_id" => parse_integer(link_params["telegram_id"]),
      "person_id" => blank_to_nil(link_params["person_id"]),
      "user_id" => blank_to_nil(link_params["user_id"])
    }

    case Telegram.Links.create_link(space_id, attrs) do
      {:ok, _link} ->
        telegram_links = Telegram.Links.list_links(space_id)

        {:noreply,
         socket
         |> assign(telegram_links: telegram_links)
         |> put_flash(:info, gettext("Telegram link added."))}

      {:error, _changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not add Telegram link. The ID may already be linked in this space.")
         )}
    end
  end

  def handle_event("delete_telegram_link", %{"id" => id}, socket) do
    link = Telegram.Links.get_link!(id)

    case Telegram.Links.delete_link(link) do
      {:ok, _} ->
        telegram_links = Telegram.Links.list_links(socket.assigns.current_scope.space.id)

        {:noreply,
         socket
         |> assign(telegram_links: telegram_links)
         |> put_flash(:info, gettext("Telegram link removed."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not remove Telegram link."))}
    end
  end

  defp assign_telegram_forms(socket) do
    space = socket.assigns.current_scope.space

    telegram_token_form =
      to_form(
        %{"telegram_bot_token" => space.telegram_bot_token || ""},
        as: "telegram_token"
      )

    assign(socket,
      telegram_token_form: telegram_token_form,
      new_link_form: to_form(%{}, as: "link")
    )
  end

  defp manage_poller(old_token, updated_space) do
    new_token = updated_space.telegram_bot_token

    cond do
      (new_token == nil or new_token == "") and old_token not in [nil, ""] ->
        Telegram.Supervisor.stop_poller(updated_space.id)

      new_token not in [nil, ""] ->
        Telegram.Supervisor.restart_poller(updated_space.id, new_token)

      true ->
        :ok
    end
  end

  defp display_role("admin"), do: gettext("admin")
  defp display_role("member"), do: gettext("member")
  defp display_role(role), do: role

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(str) when is_binary(str) do
    case Integer.parse(String.trim(str)) do
      {id, ""} -> id
      _ -> nil
    end
  end

  defp parse_integer(val), do: val

  @impl true
  def handle_info(:people_changed, socket) do
    people = Meddie.People.list_people(socket.assigns.current_scope)
    {:noreply, assign(socket, :people, people)}
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(val), do: val
end
