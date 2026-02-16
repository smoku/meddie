defmodule MeddieWeb.PeopleLive.Index do
  use MeddieWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar
      flash={@flash}
      current_scope={@current_scope}
      user_spaces={@user_spaces}
      people={@people}
      page_title={gettext("People")}
    >
      <div></div>
    </Layouts.sidebar>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.people do
      [first | _] ->
        {:ok, push_navigate(socket, to: ~p"/people/#{first}")}

      [] ->
        {:ok, push_navigate(socket, to: ~p"/people/new")}
    end
  end

  @impl true
  def handle_info(:people_changed, socket) do
    people = Meddie.People.list_people(socket.assigns.current_scope)
    {:noreply, assign(socket, :people, people)}
  end
end
