defmodule MeddieWeb.PeopleLive.Index do
  use MeddieWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.sidebar flash={@flash} current_scope={@current_scope} user_spaces={@user_spaces} page_title="People">
      <div class="max-w-4xl">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold">People</h1>
        </div>

        <div class="text-center py-12 text-base-content/50">
          <.icon name="hero-users" class="size-12 mx-auto mb-4" />
          <p class="text-lg">No people yet.</p>
          <p class="text-sm mt-1">Add your first person to start tracking health data.</p>
        </div>
      </div>
    </Layouts.sidebar>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "People")}
  end
end
