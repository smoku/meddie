defmodule MeddieWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality.
  """
  use MeddieWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders a simple centered layout for auth pages.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main class="min-h-screen flex items-center justify-center px-4 py-12 bg-gradient-to-br from-base-200 via-base-100 to-base-200">
      <div class="w-full max-w-sm">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the main app layout with sidebar and top bar.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, required: true
  attr :user_spaces, :list, default: []
  attr :people, :list, default: []
  attr :active_person_id, :string, default: nil
  attr :page_title, :string, default: nil
  slot :inner_block, required: true

  def sidebar(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden">
      <%!-- Sidebar --%>
      <aside class="hidden lg:flex flex-col w-60 bg-base-200 shadow-elevated">
        <%!-- Logo --%>
        <div class="px-5 py-5">
          <div class="flex items-center gap-2.5">
            <img src={~p"/images/icon.svg"} alt="Meddie" class="w-12 h-12" />
            <span class="text-lg font-bold tracking-tight">Meddie</span>
          </div>
        </div>

        <%!-- Ask Meddie --%>
        <nav class="px-3 space-y-0.5">
          <.sidebar_link
            href={~p"/ask-meddie"}
            icon="hero-chat-bubble-left-right"
            label={gettext("Ask Meddie")}
            active={@page_title == gettext("Ask Meddie")}
          />
        </nav>

        <%!-- People section --%>
        <div class="flex-1 flex flex-col min-h-0 mt-4">
          <div class="flex items-center justify-between px-5 mb-2">
            <span class="text-xs font-semibold uppercase tracking-wider text-base-content/40">
              {gettext("People")}
            </span>
            <.link navigate={~p"/people/new"} class="btn btn-ghost btn-xs btn-square">
              <.icon name="hero-plus-micro" class="size-3.5" />
            </.link>
          </div>

          <nav class="flex-1 overflow-y-auto px-3 space-y-0.5">
            <div :if={@people == []} class="text-center py-6 text-base-content/40 text-xs">
              {gettext("No people yet.")}
            </div>
            <.link
              :for={person <- @people}
              navigate={~p"/people/#{person}"}
              class={[
                "flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm transition-all duration-150",
                @active_person_id == person.id &&
                  "bg-primary/10 text-primary font-semibold",
                @active_person_id != person.id && "hover:bg-base-300/50"
              ]}
              data-person-name={String.downcase(person.name)}
            >
              <div class="w-7 h-7 rounded-full bg-gradient-brand flex items-center justify-center text-white font-semibold text-xs shrink-0">
                {String.first(person.name)}
              </div>
              <span class="truncate">{person.name}</span>
            </.link>
          </nav>
        </div>

        <%!-- Bottom: Settings --%>
        <div class="mt-auto px-3 pb-4">
          <.sidebar_link
            href={~p"/settings"}
            icon="hero-cog-6-tooth"
            label={gettext("Settings")}
            active={@page_title == gettext("Settings")}
          />
        </div>
      </aside>

      <%!-- Main content area --%>
      <div class="flex-1 flex flex-col overflow-hidden">
        <%!-- Top bar --%>
        <header class="navbar bg-base-100/80 glass-subtle border-b border-base-300/50 px-6 sticky top-0 z-40">
          <div class="flex-1">
            <%!-- Mobile hamburger --%>
            <label for="sidebar-drawer" class="btn btn-ghost btn-sm lg:hidden">
              <.icon name="hero-bars-3" class="size-5" />
            </label>

            <%!-- Space switcher --%>
            <div :if={@current_scope && @current_scope.space} class="dropdown">
              <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1">
                {@current_scope.space.name}
                <.icon name="hero-chevron-up-down-micro" class="size-4 opacity-60" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-elevated-lg bg-base-100 rounded-xl w-56 z-50 border border-base-300/50"
              >
                <li :for={space <- @user_spaces}>
                  <.link
                    href={~p"/spaces/#{space.id}/switch"}
                    method="post"
                    class={[space.id == @current_scope.space.id && "active"]}
                  >
                    <span class="w-4 inline-flex justify-center shrink-0">
                      <.icon
                        :if={space.id == @current_scope.space.id}
                        name="hero-check-micro"
                        class="size-4"
                      />
                    </span>
                    <span>{space.name}</span>
                  </.link>
                </li>
                <li class="border-t border-base-300 mt-1 pt-1">
                  <.link navigate={~p"/spaces/new"}>
                    <span class="w-4 inline-flex justify-center shrink-0">
                      <.icon name="hero-plus-micro" class="size-4" />
                    </span>
                    <span>{gettext("Create new Space")}</span>
                  </.link>
                </li>
              </ul>
            </div>
          </div>

          <div class="flex-none flex items-center gap-2">
            <.link
              :if={@current_scope && @current_scope.user && @current_scope.user.platform_admin}
              href={~p"/platform"}
              class="btn btn-ghost btn-sm"
            >
              {gettext("Platform")}
            </.link>

            <div :if={@current_scope && @current_scope.user} class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
                {@current_scope.user.name || @current_scope.user.email}
                <.icon name="hero-chevron-down-micro" class="size-4" />
              </div>
              <ul
                tabindex="0"
                class="dropdown-content menu p-2 shadow-elevated-lg bg-base-100 rounded-xl w-48 z-50 border border-base-300/50"
              >
                <li>
                  <.link href={~p"/users/settings"}>{gettext("Account settings")}</.link>
                </li>
                <li>
                  <.link href={~p"/users/log-out"} method="delete">{gettext("Sign out")}</.link>
                </li>
              </ul>
            </div>
          </div>
        </header>

        <%!-- Page content --%>
        <main class="flex-1 overflow-auto p-4 sm:p-6 lg:p-8 bg-base-100">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  defp sidebar_link(assigns) do
    assigns = assign_new(assigns, :disabled, fn -> false end)

    ~H"""
    <.link
      navigate={unless @disabled, do: @href}
      class={[
        "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all duration-150",
        @active && "bg-primary/10 text-primary font-semibold border-l-2 border-primary",
        !@active && !@disabled && "hover:bg-base-300/50",
        @disabled && "opacity-40 cursor-not-allowed"
      ]}
    >
      <.icon name={@icon} class="size-5" />
      <span>{@label}</span>
    </.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
