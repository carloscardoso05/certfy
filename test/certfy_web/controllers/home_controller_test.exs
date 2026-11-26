defmodule CertfyWeb.HomeControllerTest do
  use CertfyWeb.ConnCase

  test "GET / redirects to the events page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/events"
  end
end
