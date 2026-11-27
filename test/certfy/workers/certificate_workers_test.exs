defmodule Certfy.Workers.CertificateWorkersTest do
  use Certfy.DataCase

  import Certfy.AccountsFixtures, only: [user_scope_fixture: 0]
  import Certfy.EventsFixtures
  import Certfy.CertificatesFixtures
  use Oban.Testing, repo: Certfy.Repo

  alias Certfy.Certificates
  alias Certfy.Workers.{GenerateCertificate, SendCertificateEmail}

  setup do
    scope = user_scope_fixture()
    event = event_with_template(scope, %{name: "Seminário 2026"})
    batch = batch_fixture(scope, event, %{name: "Lote 1"})
    participant = participant_fixture(scope, batch, %{name: "Maria da Silva"})
    Process.put(:storage_stub_body, pptx_binary())
    flush_emails()

    %{scope: scope, event: event, batch: batch, participant: participant}
  end

  test "generates the PDF and marks the certificate as ready", %{
    scope: scope,
    participant: participant
  } do
    Certificates.prepare_for_participants(scope, [participant.id])
    certificate = Certificates.get_certificate_for_participant(scope, participant.id)

    Req.Test.stub(Certfy.Certificates.PDF, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/forms/libreoffice/convert"
      Req.Test.text(conn, "%PDF-1.4 fake certificate")
    end)

    assert {:ok, _} =
             perform_job(GenerateCertificate, %{
               "certificate_id" => certificate.id,
               "version" => 0
             })

    certificate = Certificates.get_certificate!(scope, certificate.id)
    assert certificate.status == :ready
    assert certificate.version == 1
    assert certificate.pdf_path =~ "certificates/#{scope.user.id}/#{participant.id}/v1.pdf"
    assert certificate.snapshot["participante.nome"] == "Maria da Silva"
    assert certificate.page_count == 1
  end

  test "marks the certificate as failed when the renderer fails", %{
    scope: scope,
    participant: participant
  } do
    Certificates.prepare_for_participants(scope, [participant.id])
    certificate = Certificates.get_certificate_for_participant(scope, participant.id)

    Req.Test.stub(Certfy.Certificates.PDF, fn conn ->
      Req.Test.text(Plug.Conn.put_status(conn, 500), "renderer unavailable")
    end)

    assert {:error, _} =
             perform_job(GenerateCertificate, %{
               "certificate_id" => certificate.id,
               "version" => 0
             })

    certificate = Certificates.get_certificate!(scope, certificate.id)
    assert certificate.status == :failed
    assert certificate.error =~ "HTTP 500"
  end

  test "discards stale generation versions", %{scope: scope, participant: participant} do
    certificate = certificate_fixture(scope, participant, %{version: 2})

    assert {:discard, :stale_certificate} =
             perform_job(GenerateCertificate, %{
               "certificate_id" => certificate.id,
               "version" => 1
             })
  end

  test "sends the certificate with a friendly attachment filename", %{
    scope: scope,
    participant: participant
  } do
    certificate =
      certificate_fixture(scope, participant, %{
        status: :ready,
        email_status: :pending,
        version: 1
      })

    Process.put(:storage_stub_body, "%PDF-1.4 fake certificate")

    assert {:ok, _} =
             perform_job(SendCertificateEmail, %{
               "certificate_id" => certificate.id,
               "version" => 1
             })

    certificate = Certificates.get_certificate!(scope, certificate.id)
    assert certificate.email_status == :sent
    assert certificate.emailed_at

    email = receive_certificate_email("Seu certificado — Seminário 2026")
    assert email.to == [{"Maria da Silva", "some@email.com"}]
    assert [attachment] = email.attachments
    assert attachment.filename == "Certificado - Maria da Silva - Seminário 2026.pdf"
    assert attachment.content_type == "application/pdf"
  end

  test "skips sending for a participant without e-mail", %{
    scope: scope,
    batch: batch
  } do
    participant = participant_fixture(scope, batch, %{name: "Sem e-mail", email: nil})
    certificate = certificate_fixture(scope, participant, %{status: :ready, version: 1})

    assert {:discard, :participant_without_email} =
             perform_job(SendCertificateEmail, %{
               "certificate_id" => certificate.id,
               "version" => 1
             })

    certificate = Certificates.get_certificate!(scope, certificate.id)
    assert certificate.email_status == :skipped
    refute_received {:email, %Swoosh.Email{subject: "Seu certificado — Seminário 2026"}}
  end

  defp receive_certificate_email(subject) do
    receive do
      {:email, %Swoosh.Email{subject: ^subject} = email} ->
        email

      {:email, _other} ->
        receive_certificate_email(subject)
    after
      1000 -> flunk("certificate e-mail was not sent")
    end
  end

  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end
end
