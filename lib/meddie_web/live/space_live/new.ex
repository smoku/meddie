defmodule MeddieWeb.SpaceLive.New do
  use MeddieWeb, :live_view

  alias Meddie.Spaces
  alias Meddie.Spaces.Space

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center mb-8">
        <h1 class="text-2xl font-bold">{gettext("Welcome to Meddie!")}</h1>
        <p class="mt-2 text-sm text-base-content/70">
          {gettext("Create your first Space to get started.")}
        </p>
      </div>

      <.form for={@form} id="space-form" phx-submit="save" phx-change="validate" class="space-y-4">
        <.input
          field={@form[:name]}
          type="text"
          label={gettext("Space name")}
          phx-mounted={JS.focus()}
        />
        <p class="text-xs text-base-content/50">
          {gettext("A space groups people, documents and results. You can create your personal space or a family space.")}
        </p>
        <.button phx-disable-with={gettext("Creating...")} class="btn btn-primary w-full">
          {gettext("Create Space")}
        </.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    default_name = "#{user.name}'s Health"

    changeset = Spaces.change_space(%Space{}, %{name: default_name})
    {:ok, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("validate", %{"space" => space_params}, socket) do
    changeset =
      %Space{}
      |> Spaces.change_space(space_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"space" => space_params}, socket) do
    case Spaces.create_space(socket.assigns.current_scope, space_params) do
      {:ok, space} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Space created!"))
         |> redirect(to: ~p"/spaces/#{space.id}/switch")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, form: to_form(changeset, as: "space"))
  end
end
