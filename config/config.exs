# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :certfy, :scopes,
  user: [
    default: true,
    module: Certfy.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Certfy.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :certfy,
  ecto_repos: [Certfy.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure Gettext (mensagens de erro em pt-BR)
config :certfy, CertfyWeb.Gettext, default_locale: "pt_BR"

# Product identity. Deployments can override these values at runtime with
# BRAND_NAME, BRAND_THEME and BRAND_FROM_EMAIL (see config/runtime.exs).
config :certfy, :branding,
  name: "Certfy",
  theme: "certfy",
  mark: "certfy",
  from_email: "no-reply@certfy.local"

# Configure the endpoint
config :certfy, CertfyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CertfyWeb.ErrorHTML, json: CertfyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Certfy.PubSub,
  live_view: [signing_salt: "qcFMcKji"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :certfy, Certfy.Mailer, adapter: Swoosh.Adapters.Local

# Background jobs for certificate generation and e-mail delivery
config :certfy, Oban,
  repo: Certfy.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, certificates: 2, emails: 5]

# Certificate generation
config :certfy, :certificates,
  pdf_url: "http://localhost:3000",
  max_attachment_bytes: 15_000_000,
  from_email: "no-reply@certfy.local",
  from_name: "Certfy"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  certfy: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  certfy: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure S3-compatible object storage (RustFS)
config :ex_aws,
  http_client: ExAws.Request.Req

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000

config :certfy, :storage, bucket: "certfy-templates"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
