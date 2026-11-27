defmodule CertfyWeb.TemplateControllerTest do
  use CertfyWeb.ConnCase

  import Certfy.EventsFixtures
  import Certfy.CertificatesFixtures

  setup :register_and_log_in_user

  test "downloads the pptx template", %{conn: conn, scope: scope} do
    event = event_with_template(scope)
    Process.put(:storage_stub_body, pptx_binary())

    conn = get(conn, ~p"/events/#{event}/template/download")

    assert response(conn, 200) == pptx_binary()
    assert get_resp_header(conn, "content-type") |> hd() =~ "presentationml"
  end

  test "previews with sample data through LibreOffice", %{conn: conn, scope: scope} do
    event = event_with_template(scope)
    Process.put(:storage_stub_body, pptx_binary())

    Req.Test.stub(Certfy.Certificates.PDF, fn conn ->
      assert conn.request_path == "/forms/libreoffice/convert"
      Req.Test.text(conn, "%PDF-1.7 preview")
    end)

    conn = get(conn, ~p"/events/#{event}/template/preview?sample=1")

    assert response(conn, 200) == "%PDF-1.7 preview"
    assert get_resp_header(conn, "content-type") |> hd() =~ "application/pdf"
  end

  test "blocks data preview when the template is malformed", %{conn: conn, scope: scope} do
    event =
      event_fixture(scope, %{
        template_path: template_path(),
        template_report: invalid_pptx_report()
      })

    conn = get(conn, ~p"/events/#{event}/template/preview?sample=1")

    assert response(conn, 422) =~ "tags malformadas"
  end
end
