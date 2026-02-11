defmodule MeddieWeb.Router do
  use MeddieWeb, :router

  import MeddieWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MeddieWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Redirect root to /people (which will redirect to login if not authenticated)
  scope "/", MeddieWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:meddie, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MeddieWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  # Public: invitation acceptance (controller, not LiveView)
  scope "/", MeddieWeb do
    pipe_through [:browser]

    get "/invitations/:token", InvitationController, :show
    post "/invitations/:token/accept", InvitationController, :accept
  end

  # Public: login
  scope "/", MeddieWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{MeddieWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  # Authenticated: controller routes (no space required)
  scope "/", MeddieWeb do
    pipe_through [:browser, :require_authenticated_user]

    post "/users/update-password", UserSessionController, :update_password
    get "/spaces/:id/switch", SpaceController, :switch
    post "/spaces/:id/switch", SpaceController, :switch
  end

  # Authenticated: create first space (no space required)
  scope "/", MeddieWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :no_space,
      on_mount: [{MeddieWeb.UserAuth, :require_authenticated}] do
      live "/spaces/new", SpaceLive.New, :new
    end
  end

  # Authenticated + space required: main app
  scope "/", MeddieWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :app,
      on_mount: [
        {MeddieWeb.UserAuth, :require_authenticated},
        {MeddieWeb.UserAuth, :ensure_current_space}
      ] do
      live "/people", PeopleLive.Index, :index
      live "/people/new", PeopleLive.Form, :new
      live "/people/:id", PeopleLive.Show, :show
      live "/people/:id/edit", PeopleLive.Form, :edit
      live "/people/:person_id/documents/:id", DocumentLive.Show, :show
      live "/ask-meddie", AskMeddieLive.Index, :index
      live "/ask-meddie/new", AskMeddieLive.Show, :new
      live "/ask-meddie/:id", AskMeddieLive.Show, :show
      live "/settings", SettingsLive.Index, :index
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end
  end

  # Platform admin
  scope "/", MeddieWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :platform_admin,
      on_mount: [
        {MeddieWeb.UserAuth, :require_authenticated},
        {MeddieWeb.UserAuth, :require_platform_admin}
      ] do
      live "/platform", PlatformLive.Index, :index
    end
  end
end
