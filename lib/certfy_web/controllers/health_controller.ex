defmodule CertfyWeb.HealthController do
  @moduledoc """
  Liveness probe used by the container orchestrator.
  """

  use CertfyWeb, :controller

  def index(conn, _params) do
    send_resp(conn, :ok, "ok")
  end
end
