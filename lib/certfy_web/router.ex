defmodule CertfyWeb.Router do
  use CertfyWeb, :router

  import CertfyWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CertfyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CertfyWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", CertfyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:certfy, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CertfyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", CertfyWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{CertfyWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Form, :new
      live "/events/:id", EventLive.Show, :show
      live "/events/:id/edit", EventLive.Form, :edit

      live "/events/:event_id/batches", BatchLive.Index, :index
      live "/events/:event_id/batches/new", BatchLive.Form, :new
      live "/events/:event_id/batches/:id", BatchLive.Show, :show
      live "/events/:event_id/batches/:id/edit", BatchLive.Form, :edit

      live "/events/:event_id/batches/:batch_id/participants", ParticipantLive.Index, :index
      live "/events/:event_id/batches/:batch_id/participants/new", ParticipantLive.Form, :new
      live "/events/:event_id/batches/:batch_id/participants/:id", ParticipantLive.Show, :show

      live "/events/:event_id/batches/:batch_id/participants/:id/edit",
           ParticipantLive.Form,
           :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", CertfyWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{CertfyWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
