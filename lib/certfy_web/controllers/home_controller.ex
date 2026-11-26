defmodule CertfyWeb.HomeController do
  use CertfyWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: ~p"/events")
  end
end
