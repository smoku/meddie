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
      <div class="max-w-4xl">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold">{gettext("People")}</h1>
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
            <.icon name="hero-users" class="size-12 mx-auto mb-4" />
            <p class="text-lg">{gettext("No people yet.")}</p>
            <p class="text-sm mt-1">
              {gettext("Add your first person to start tracking health data.")}
            </p>
          </div>

          <.link
            :for={{dom_id, person} <- @streams.people}
            navigate={~p"/people/#{person}"}
            id={dom_id}
            class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow cursor-pointer"
          >
            <div class="card-body p-4">
              <h2 class="card-title text-base">{person.name}</h2>
              <div class="text-sm text-base-content/60 flex items-center gap-2">
                <span>{display_sex(person.sex)}</span>
                <span :if={person.date_of_birth}>
                  &middot; {age(person.date_of_birth)} {gettext("y.o.")}
                </span>
              </div>
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
