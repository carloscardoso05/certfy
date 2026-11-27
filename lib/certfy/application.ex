defmodule Certfy.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CertfyWeb.Telemetry,
      Certfy.Repo,
      {DNSCluster, query: Application.get_env(:certfy, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Certfy.PubSub},
      {Oban, Application.fetch_env!(:certfy, Oban)},
      # Start a worker by calling: Certfy.Worker.start_link(arg)
      # {Certfy.Worker, arg},
      # Start to serve requests, typically the last entry
      CertfyWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Certfy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CertfyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
