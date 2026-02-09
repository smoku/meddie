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
    <main class="min-h-screen flex items-center justify-center px-4 py-12">
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
  attr :page_title, :string, default: nil
  slot :inner_block, required: true

  def sidebar(assigns) do
    ~H"""
    <div class="flex h-screen overflow-hidden">
      <%!-- Sidebar --%>
      <aside class="hidden lg:flex flex-col w-56 border-r border-base-300 bg-base-200">
        <div class="p-4">
          <span class="text-lg font-bold">Meddie</span>
        </div>

        <nav class="flex-1 px-2 space-y-1">
          <.sidebar_link
            href={~p"/people"}
            icon="hero-users"
            label="People"
            active={@page_title == "People"}
          />
          <.sidebar_link
            href="#"
            icon="hero-chat-bubble-left-right"
            label="Chat"
            active={false}
            disabled={true}
          />
          <.sidebar_link
            href="#"
            icon="hero-paper-airplane"
            label="Telegram"
            active={false}
            disabled={true}
          />
          <.sidebar_link
            href={~p"/settings"}
            icon="hero-cog-6-tooth"
            label="Settings"
            active={@page_title == "Settings"}
          />
        </nav>
      </aside>

      <%!-- Main content area --%>
      <div class="flex-1 flex flex-col overflow-hidden">
        <%!-- Top bar --%>
        <header class="navbar border-b border-base-300 px-4">
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
              <ul tabindex="0" class="dropdown-content menu p-2 shadow-lg bg-base-100 rounded-box w-56 z-50">
                <li :for={space <- @user_spaces}>
                  <.link
                    href={~p"/spaces/#{space.id}/switch"}
                    method="post"
                    class={[space.id == @current_scope.space.id && "active"]}
                  >
                    <.icon
                      :if={space.id == @current_scope.space.id}
                      name="hero-check-micro"
                      class="size-4"
                    />
                    <span class={[space.id != @current_scope.space.id && "ml-8"]}>
                      {space.name}
                    </span>
                  </.link>
                </li>
                <li class="border-t border-base-300 mt-1 pt-1">
                  <.link navigate={~p"/spaces/new"}>
                    <.icon name="hero-plus-micro" class="size-4" />
                    <span>Create new Space</span>
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
              Platform
            </.link>

            <.theme_toggle />

            <div :if={@current_scope && @current_scope.user} class="dropdown dropdown-end">
              <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
                {@current_scope.user.name || @current_scope.user.email}
                <.icon name="hero-chevron-down-micro" class="size-4" />
              </div>
              <ul tabindex="0" class="dropdown-content menu p-2 shadow-lg bg-base-100 rounded-box w-48 z-50">
                <li>
                  <.link href={~p"/users/settings"}>Account settings</.link>
                </li>
                <li>
                  <.link href={~p"/users/log-out"} method="delete">Sign out</.link>
                </li>
              </ul>
            </div>
          </div>
        </header>

        <%!-- Page content --%>
        <main class="flex-1 overflow-auto p-4 sm:p-6 lg:p-8">
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
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm",
        @active && "bg-base-300 font-semibold",
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

  @doc """
  Provides dark vs light theme toggle.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />
      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system">
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light">
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark">
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
