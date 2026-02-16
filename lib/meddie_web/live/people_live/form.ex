defmodule MeddieWeb.PeopleLive.Form do
  use MeddieWeb, :live_view

  alias Meddie.People
  alias Meddie.People.Person
  alias Meddie.Spaces

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      people={@people}
      active_person_id={if @person, do: @person.id}
      page_title={@page_title}
    >
      <div class="max-w-2xl">
        <div class="flex items-center gap-3 mb-6">
          <.link navigate={@back_path} class="btn btn-ghost btn-sm">
            <.icon name="hero-arrow-left-micro" class="size-4" />
          </.link>
          <h1 class="text-2xl font-bold">{@page_title}</h1>
        </div>

        <.form for={@form} id="person-form" phx-change="validate" phx-submit="save" class="space-y-6">
          <div class="card bg-base-100 shadow-elevated border border-base-300/20">
            <div class="card-body">
              <h3 class="card-title text-base">{gettext("Basic information")}</h3>
              <.input field={@form[:name]} type="text" label={gettext("Name")} required />
              <.input
                field={@form[:sex]}
                type="select"
                label={gettext("Biological sex")}
                prompt={gettext("Select...")}
                options={[{gettext("Male"), "male"}, {gettext("Female"), "female"}]}
                required
              />
              <.input
                field={@form[:date_of_birth]}
                type="date"
                label={gettext("Date of birth")}
              />
              <.input
                field={@form[:height_cm]}
                type="number"
                label={gettext("Height (cm)")}
              />
              <.input
                field={@form[:weight_kg]}
                type="number"
                label={gettext("Weight (kg)")}
                step="0.1"
              />
              <.input
                field={@form[:user_id]}
                type="select"
                label={gettext("Linked user")}
                prompt={gettext("None")}
                options={@user_options}
              />
            </div>
          </div>

          <div :if={@live_action == :edit} class="card bg-base-100 shadow-elevated border border-base-300/20">
            <div class="card-body space-y-4">
              <h3 class="card-title text-base">{gettext("Health information")}</h3>
              <div id="editor-health-notes" phx-hook="MarkdownEditor" phx-update="ignore">
                <.input
                  field={@form[:health_notes]}
                  type="textarea"
                  label={gettext("Health Notes")}
                  rows="6"
                />
              </div>
              <div id="editor-supplements" phx-hook="MarkdownEditor" phx-update="ignore">
                <.input
                  field={@form[:supplements]}
                  type="textarea"
                  label={gettext("Supplements")}
                  rows="6"
                />
              </div>
              <div id="editor-medications" phx-hook="MarkdownEditor" phx-update="ignore">
                <.input
                  field={@form[:medications]}
                  type="textarea"
                  label={gettext("Medications")}
                  rows="6"
                />
              </div>
            </div>
          </div>

          <div class="flex justify-end">
            <.button variant="primary" phx-disable-with={gettext("Saving...")}>
              {gettext("Save")}
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.sidebar>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)
    {:ok, socket}
  end

  defp apply_action(socket, :new, _params) do
    changeset = People.change_person(%Person{})

    socket
    |> assign(page_title: gettext("Add person"))
    |> assign(person: nil)
    |> assign(back_path: ~p"/people")
    |> assign_user_options()
    |> assign_form(changeset)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    person = People.get_person!(scope, id)
    changeset = People.change_person(person)

    socket
    |> assign(page_title: gettext("Edit person"))
    |> assign(person: person)
    |> assign(back_path: ~p"/people/#{person}")
    |> assign_user_options()
    |> assign_form(changeset)
  end

  @impl true
  def handle_event("validate", %{"person" => person_params}, socket) do
    person = socket.assigns.person || %Person{}

    changeset =
      person
      |> People.change_person(person_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"person" => person_params}, socket) do
    save_person(socket, socket.assigns.live_action, person_params)
  end

  @impl true
  def handle_info(:people_changed, socket) do
    people = People.list_people(socket.assigns.current_scope)
    {:noreply, assign(socket, :people, people)}
  end

  defp save_person(socket, :new, person_params) do
    case People.create_person(socket.assigns.current_scope, person_params) do
      {:ok, person} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Person created successfully."))
         |> push_navigate(to: ~p"/people/#{person}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_person(socket, :edit, person_params) do
    case People.update_person(socket.assigns.current_scope, socket.assigns.person, person_params) do
      {:ok, person} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Person updated successfully."))
         |> push_navigate(to: ~p"/people/#{person}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_user_options(socket) do
    members = Spaces.list_space_members(socket.assigns.current_scope)

    options =
      Enum.map(members, fn membership ->
        {membership.user.name || membership.user.email, membership.user.id}
      end)

    assign(socket, user_options: options)
  end

  defp assign_form(socket, changeset) do
    assign(socket, form: to_form(changeset))
  end
end
