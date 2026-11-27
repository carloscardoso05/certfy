defmodule CertfyWeb.SSLRedirect do
  @moduledoc """
  Applies `Plug.SSL` when the deployment serves HTTPS.

  `force_ssl` is baked at compile time by `Phoenix.Endpoint`, so it cannot be
  toggled per deployment. This plug reads the runtime flag instead, allowing the
  same image to run behind Traefik with TLS (`FORCE_SSL=true`) or exposed on a
  plain HTTP port (`FORCE_SSL=false`).
  """

  @behaviour Plug

  @options [
    hsts: true,
    rewrite_on: [:x_forwarded_proto],
    exclude: [
      paths: ["/health"],
      hosts: ["localhost", "127.0.0.1"]
    ]
  ]

  @impl true
  def init(_opts) do
    @options
    |> Keyword.put_new(:host, {CertfyWeb.Endpoint, :host, []})
    |> Plug.SSL.init()
  end

  @impl true
  def call(conn, opts) do
    if Application.get_env(:certfy, :force_ssl, false) do
      Plug.SSL.call(conn, opts)
    else
      conn
    end
  end
end
