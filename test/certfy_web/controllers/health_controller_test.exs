defmodule CertfyWeb.HealthControllerTest do
  use CertfyWeb.ConnCase, async: true

  test "returns ok for the container healthcheck", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert conn.status == 200
    assert conn.resp_body == "ok"
  end
end
