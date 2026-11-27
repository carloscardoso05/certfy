defmodule CertfyWeb.CertificateControllerTest do
  use CertfyWeb.ConnCase

  import Certfy.CertificatesFixtures
  import Certfy.EventsFixtures

  setup :register_and_log_in_user

  describe "GET /validar" do
    test "renders the validation form", %{conn: conn} do
      conn = get(conn, ~p"/validar")

      html = html_response(conn, 200)
      assert html =~ "Validar certificado"
      assert html =~ "Código de 10 caracteres"
    end

    test "shows a valid certificate", %{conn: conn, scope: scope} do
      event = event_fixture(scope, %{name: "Seminário 2026"})
      batch = batch_fixture(scope, event, %{name: "Lote 1"})
      participant = participant_fixture(scope, batch, %{name: "Maria da Silva"})
      certificate = certificate_fixture(scope, participant)

      conn = get(conn, ~p"/validar/#{certificate.code}")

      html = html_response(conn, 200)
      assert html =~ "Certificado válido"
      assert html =~ "Maria da Silva"
      assert html =~ "Seminário 2026"
      assert html =~ certificate.code
    end

    test "shows an error for an unknown code", %{conn: conn} do
      conn = get(conn, ~p"/validar/ZZZZZZZZZZ")

      html = html_response(conn, 200)
      assert html =~ "Nenhum certificado encontrado"
    end
  end

  describe "GET /certificates/:id/download" do
    test "downloads the certificate with a friendly filename", %{conn: conn, scope: scope} do
      event = event_fixture(scope, %{name: "Seminário 2026"})
      batch = batch_fixture(scope, event)
      participant = participant_fixture(scope, batch, %{name: "Maria da Silva"})
      certificate = certificate_fixture(scope, participant)

      Process.put(:storage_stub_body, "%PDF-1.4 certificate")

      conn = get(conn, ~p"/certificates/#{certificate}/download")

      assert response(conn, 200) == "%PDF-1.4 certificate"

      header =
        conn
        |> get_resp_header("content-disposition")
        |> hd()

      assert URI.decode(header) =~ "Certificado - Maria da Silva - Seminário 2026.pdf"
    end
  end
end
