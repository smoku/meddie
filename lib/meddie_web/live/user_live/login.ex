defmodule MeddieWeb.UserLive.Login do
  use MeddieWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-6">
        <div class="text-center">
          <div class="flex items-center justify-center gap-2.5 mb-6">
            <img src={~p"/images/icon.svg"} alt="Meddie" class="w-14 h-14" />
            <span class="text-2xl font-bold tracking-tight">Meddie</span>
          </div>
          <.header>
            <p>{gettext("Log in")}</p>
            <:subtitle>
              {gettext("Sign in to your Meddie account.")}
            </:subtitle>
          </.header>
        </div>

        <div class="card bg-base-100 shadow-elevated-lg border border-base-300/20 p-6">
        <.form
          for={@form}
          id="login_form"
          action={~p"/users/log-in"}
          phx-submit="submit"
          phx-trigger-action={@trigger_submit}
        >
          <.input
            field={@form[:email]}
            type="email"
            label={gettext("Email")}
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:password]}
            type="password"
            label={gettext("Password")}
            autocomplete="current-password"
          />
          <input type="hidden" name={@form[:remember_me].name} value="true" />
          <.button class="btn btn-primary w-full">
            {gettext("Log in")}
          </.button>
        </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
