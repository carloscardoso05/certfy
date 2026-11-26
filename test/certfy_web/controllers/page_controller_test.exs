defmodule CertfyWeb.PageControllerTest do
  use CertfyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Tranquilidade do protótipo à produção"
  end
end
