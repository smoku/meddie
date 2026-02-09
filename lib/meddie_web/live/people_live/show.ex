defmodule MeddieWeb.PeopleLive.Show do
  use MeddieWeb, :live_view

  alias Meddie.People

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      page_title={@person.name}
    >
      <div class="max-w-4xl space-y-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <.link navigate={~p"/people"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left-micro" class="size-4" />
            </.link>
            <h1 class="text-2xl font-bold">{@person.name}</h1>
          </div>
          <div class="flex gap-2">
            <.link navigate={~p"/people/#{@person}/edit"} class="btn btn-ghost btn-sm">
              <.icon name="hero-pencil-square-micro" class="size-4" />
              {gettext("Edit")}
            </.link>
            <button
              phx-click="delete"
              data-confirm={
                gettext(
                  "This will permanently delete this person and all their documents, biomarkers, and conversations. This action cannot be undone."
                )
              }
              class="btn btn-ghost btn-sm text-error"
            >
              <.icon name="hero-trash-micro" class="size-4" />
              {gettext("Delete")}
            </button>
          </div>
        </div>

        <%!-- Profile card --%>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <h3 class="card-title text-base">{gettext("Profile")}</h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 mt-2">
              <.info_item label={gettext("Sex")} value={display_sex(@person.sex)} />
              <.info_item
                label={gettext("Date of birth")}
                value={
                  if @person.date_of_birth,
                    do: Calendar.strftime(@person.date_of_birth, "%Y-%m-%d"),
                    else: "—"
                }
              />
              <.info_item
                label={gettext("Age")}
                value={if @person.date_of_birth, do: "#{age(@person.date_of_birth)}", else: "—"}
              />
              <.info_item
                label={gettext("Height")}
                value={if @person.height_cm, do: "#{@person.height_cm} cm", else: "—"}
              />
              <.info_item
                label={gettext("Weight")}
                value={if @person.weight_kg, do: "#{@person.weight_kg} kg", else: "—"}
              />
            </div>
          </div>
        </div>

        <%!-- Health Notes --%>
        <.markdown_card title={gettext("Health Notes")} content={@person.health_notes} />

        <%!-- Supplements --%>
        <.markdown_card title={gettext("Supplements")} content={@person.supplements} />

        <%!-- Medications --%>
        <.markdown_card title={gettext("Medications")} content={@person.medications} />
      </div>
    </Layouts.sidebar>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp info_item(assigns) do
    ~H"""
    <div>
      <dt class="text-xs text-base-content/50 uppercase tracking-wide">{@label}</dt>
      <dd class="mt-1 text-sm font-medium">{@value}</dd>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :content, :string, default: nil

  defp markdown_card(assigns) do
    assigns = assign(assigns, :rendered, render_markdown(assigns.content))

    ~H"""
    <div class="card bg-base-100 shadow-sm">
      <div class="card-body">
        <h3 class="card-title text-base">{@title}</h3>
        <div class="mt-2 text-sm markdown-content text-base-content/80">
          {@rendered}
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    person = People.get_person!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(page_title: person.name)
     |> assign(person: person)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = People.delete_person(socket.assigns.current_scope, socket.assigns.person)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Person deleted successfully."))
     |> push_navigate(to: ~p"/people")}
  end

  defp age(date_of_birth) do
    div(Date.diff(Date.utc_today(), date_of_birth), 365)
  end

  defp render_markdown(nil), do: "—"
  defp render_markdown(""), do: "—"

  defp render_markdown(content) do
    content
    |> Earmark.as_html!(smartypants: false)
    |> Phoenix.HTML.raw()
  end

  defp display_sex("male"), do: gettext("Male")
  defp display_sex("female"), do: gettext("Female")
  defp display_sex(_), do: ""
end
