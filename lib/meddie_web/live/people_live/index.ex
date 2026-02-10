defmodule MeddieWeb.PeopleLive.Index do
  use MeddieWeb, :live_view

  alias Meddie.People

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      page_title={gettext("People")}
    >
      <div class="max-w-5xl">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold tracking-tight">{gettext("People")}</h1>
          <.link navigate={~p"/people/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus-micro" class="size-4" />
            {gettext("Add person")}
          </.link>
        </div>

        <div id="people" phx-update="stream" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div
            id="people-empty"
            class="hidden only:block col-span-full text-center py-12 text-base-content/50"
          >
            <div class="w-16 h-16 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-4">
              <.icon name="hero-users" class="size-8 text-base-content/30" />
            </div>
            <p class="text-lg font-medium">{gettext("No people yet.")}</p>
            <p class="text-sm mt-1">
              {gettext("Add your first person to start tracking health data.")}
            </p>
          </div>

          <.link
            :for={{dom_id, person} <- @streams.people}
            navigate={~p"/people/#{person}"}
            id={dom_id}
            class="card bg-base-100 shadow-elevated hover:shadow-elevated-lg hover:-translate-y-0.5 transition-all duration-200 cursor-pointer border border-base-300/30"
          >
            <div class="card-body p-4 flex-row items-center gap-4">
              <div class="w-11 h-11 rounded-full bg-gradient-brand flex items-center justify-center text-white font-semibold text-sm shrink-0">
                {String.first(person.name)}
              </div>
              <div class="flex-1 min-w-0">
                <h2 class="font-semibold text-base truncate">{person.name}</h2>
                <div class="text-sm text-base-content/50 flex items-center gap-2">
                  <span>{display_sex(person.sex)}</span>
                  <span :if={person.date_of_birth}>
                    &middot; {age(person.date_of_birth)} {gettext("y.o.")}
                  </span>
                </div>
              </div>
              <.icon name="hero-chevron-right-micro" class="size-4 text-base-content/30 shrink-0" />
            </div>
          </.link>
        </div>
      </div>
    </Layouts.sidebar>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    people = People.list_people(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(page_title: gettext("People"))
     |> stream(:people, people)}
  end

  defp age(date_of_birth) do
    today = Date.utc_today()
    div(Date.diff(today, date_of_birth), 365)
  end

  defp display_sex("male"), do: gettext("Male")
  defp display_sex("female"), do: gettext("Female")
  defp display_sex(_), do: ""
end
