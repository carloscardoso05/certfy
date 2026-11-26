defmodule CertfyWeb.PageController do
  use CertfyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
