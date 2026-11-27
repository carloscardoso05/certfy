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

    get "/", HomeController, :index

    get "/validar", CertificateController, :validate
    get "/validar/:code", CertificateController, :validate
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

  @auth_hooks [{CertfyWeb.UserAuth, :require_authenticated}]

  scope "/", CertfyWeb do
    pipe_through [:browser, :require_authenticated_user]

    scope "/users" do
      live_session :user_settings, on_mount: @auth_hooks do
        live "/settings", UserLive.Settings, :edit
        live "/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      end

      live_session :admin_users,
        on_mount: @auth_hooks ++ [{CertfyWeb.UserAuth, :require_admin}] do
        live "/", UserLive.Index, :index
      end
    end

    live_session :app, on_mount: @auth_hooks do
      get "/certificates/:id/download", CertificateController, :download

      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Form, :new
      live "/events/:id/template", EventLive.Template, :show
      get "/events/:id/template/download", TemplateController, :download
      get "/events/:id/template/preview", TemplateController, :preview
      live "/events/:id", EventLive.Show, :show
      live "/events/:id/edit", EventLive.Form, :edit

      live "/batches", BatchLive.Index, :index
      live "/batches/new", BatchLive.Form, :new
      live "/batches/:id", BatchLive.Show, :show
      live "/batches/:id/edit", BatchLive.Form, :edit

      live "/participants", ParticipantLive.Index, :index
      live "/participants/new", ParticipantLive.Form, :new
      live "/participants/:id", ParticipantLive.Show, :show
      live "/participants/:id/edit", ParticipantLive.Form, :edit
    end
  end

  scope "/", CertfyWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{CertfyWeb.UserAuth, :mount_current_scope}] do
      live "/users/register/:token", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
