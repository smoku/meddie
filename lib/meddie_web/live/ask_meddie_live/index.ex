defmodule MeddieWeb.AskMeddieLive.Index do
  use MeddieWeb, :live_view

  alias Meddie.Conversations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      people={@people}
      page_title={gettext("Ask Meddie")}
    >
      <div class="flex h-[calc(100vh-4.25rem)] -m-4 sm:-m-6 lg:-m-8">
        <%!-- Left panel: conversation list --%>
        <aside class="hidden lg:flex flex-col w-72 border-r border-base-300/50 bg-base-200/30 shrink-0">
          <div class="flex items-center justify-between px-4 py-3 border-b border-base-300/50">
            <span class="font-bold text-sm">{gettext("Ask Meddie")}</span>
            <.link navigate={~p"/ask-meddie/new"} class="btn btn-ghost btn-sm btn-square">
              <.icon name="hero-pencil-square-micro" class="size-4" />
            </.link>
          </div>
          <nav class="flex-1 overflow-y-auto p-2 space-y-0.5">
            <.link
              :for={conv <- @conversations}
              navigate={~p"/ask-meddie/#{conv}"}
              class="flex flex-col gap-0.5 px-3 py-2.5 rounded-lg text-sm transition-all duration-150 block hover:bg-base-300/50"
            >
              <span class="truncate font-medium">{conv.title || gettext("New conversation")}</span>
              <span class="text-xs text-base-content/40 truncate">
                {conv_person_name(conv, @people)}
                &middot;
                {Calendar.strftime(conv.updated_at, "%m/%d")}
              </span>
            </.link>
            <div :if={@conversations == []} class="text-center py-8 text-base-content/40 text-xs">
              {gettext("No conversations yet.")}
            </div>
          </nav>
        </aside>

        <%!-- Right panel: welcome state --%>
        <div class="flex-1 flex flex-col items-center justify-center min-w-0 p-8">
          <.icon name="hero-chat-bubble-left-right" class="size-16 text-base-content/20 mb-4" />
          <h2 class="text-lg font-bold mb-1">{gettext("Ask Meddie")}</h2>
          <p class="text-sm text-base-content/50 mb-6 text-center max-w-md">
            {gettext("Start a new chat to ask Meddie about your health data.")}
          </p>
          <.link navigate={~p"/ask-meddie/new"} class="btn btn-primary">
            <.icon name="hero-plus-micro" class="size-4" />
            {gettext("New chat")}
          </.link>

          <%!-- Mobile: show conversation list --%>
          <div :if={@conversations != []} class="lg:hidden w-full max-w-lg mt-8 space-y-2">
            <h3 class="text-sm font-semibold text-base-content/60 px-1">{gettext("Recent conversations")}</h3>
            <.link
              :for={conv <- @conversations}
              navigate={~p"/ask-meddie/#{conv}"}
              class="flex items-center gap-3 px-4 py-3 rounded-lg bg-base-200/50 hover:bg-base-200 transition-colors block"
            >
              <.icon name="hero-chat-bubble-left-right-micro" class="size-4 text-base-content/40 shrink-0" />
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium truncate">{conv.title || gettext("New conversation")}</p>
                <p class="text-xs text-base-content/40">{conv_person_name(conv, @people)}</p>
              </div>
              <.icon name="hero-chevron-right-micro" class="size-4 text-base-content/30" />
            </.link>
          </div>
        </div>
      </div>
    </Layouts.sidebar>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    conversations = Conversations.list_conversations(scope)

    {:ok,
     socket
     |> assign(page_title: gettext("Ask Meddie"))
     |> assign(conversations: conversations)}
  end

  @impl true
  def handle_info(:people_changed, socket) do
    people = Meddie.People.list_people(socket.assigns.current_scope)
    {:noreply, assign(socket, :people, people)}
  end

  defp conv_person_name(conv, people) do
    case Enum.find(people, &(&1.id == conv.person_id)) do
      nil -> gettext("General")
      person -> person.name
    end
  end
end
