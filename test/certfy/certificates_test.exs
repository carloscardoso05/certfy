defmodule Certfy.CertificatesTest do
  use Certfy.DataCase

  import Certfy.AccountsFixtures, only: [user_scope_fixture: 0]
  import Certfy.EventsFixtures
  import Certfy.CertificatesFixtures
  use Oban.Testing, repo: Certfy.Repo

  alias Certfy.Certificates
  alias Certfy.Workers.{GenerateCertificate, SendCertificateEmail}

  setup do
    scope = user_scope_fixture()
    event = event_with_template(scope)
    batch = batch_fixture(scope, event)
    participant = participant_fixture(scope, batch, %{name: "Maria"})

    %{scope: scope, event: event, batch: batch, participant: participant}
  end

  describe "generation" do
    test "creates a certificate and enqueues a job", %{
      scope: scope,
      participant: participant
    } do
      summary = Certificates.prepare_for_participants(scope, [participant.id])

      assert summary.queued == 1
      assert summary.no_template == 0

      certificate = Certificates.get_certificate_for_participant(scope, participant.id)
      assert certificate.status == :pending
      assert certificate.version == 0
      assert String.length(certificate.code) == 10
      assert_enqueued(worker: GenerateCertificate)
    end

    test "skips participants whose event has no template", %{scope: scope} do
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)
      participant = participant_fixture(scope, batch)

      summary = Certificates.prepare_for_participants(scope, [participant.id])

      assert summary.queued == 0
      assert summary.no_template == 1
      assert is_nil(Certificates.get_certificate_for_participant(scope, participant.id))
    end

    test "blocks participants whose template has malformed tags", %{scope: scope} do
      event =
        event_fixture(scope, %{
          template_path: template_path(),
          template_report: invalid_pptx_report()
        })

      batch = batch_fixture(scope, event)
      participant = participant_fixture(scope, batch)

      summary = Certificates.prepare_for_participants(scope, [participant.id])

      assert summary.queued == 0
      assert summary.invalid_template == 1
      assert is_nil(Certificates.get_certificate_for_participant(scope, participant.id))
    end

    test "regenerates ready certificates and marks them as not sent", %{
      scope: scope,
      participant: participant
    } do
      certificate =
        certificate_fixture(scope, participant, %{
          emailed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      summary = Certificates.prepare_for_participants(scope, [participant.id])

      assert summary.queued == 1
      reloaded = Certificates.get_certificate!(scope, certificate.id)
      assert reloaded.status == :pending
      assert is_nil(reloaded.emailed_at)
      assert reloaded.email_status == :pending
    end
  end

  describe "sending" do
    test "enqueues e-mails even for certificates already sent", %{
      scope: scope,
      participant: participant
    } do
      certificate =
        certificate_fixture(scope, participant, %{
          emailed_at: DateTime.utc_now() |> DateTime.truncate(:second),
          email_status: :sent
        })

      summary = Certificates.send_emails(scope, [participant.id])

      assert summary.queued == 1
      reloaded = Certificates.get_certificate!(scope, certificate.id)
      assert reloaded.email_status == :pending
      assert_enqueued(worker: SendCertificateEmail)
    end

    test "skips participants without e-mail", %{scope: scope, batch: batch} do
      participant = participant_fixture(scope, batch, %{name: "Sem e-mail", email: nil})
      certificate_fixture(scope, participant)

      summary = Certificates.send_emails(scope, [participant.id])

      assert summary.queued == 0
      assert summary.no_email == 1
      assert all_enqueued(worker: SendCertificateEmail) == []
    end

    test "skips certificates that are not ready", %{scope: scope, participant: participant} do
      Certificates.prepare_for_participants(scope, [participant.id])

      summary = Certificates.send_emails(scope, [participant.id])

      assert summary.queued == 0
      assert summary.in_progress == 1
    end
  end

  describe "selection" do
    test "finds participants by certificate state", %{
      scope: scope,
      batch: batch,
      participant: participant
    } do
      other = participant_fixture(scope, batch, %{name: "João", email: "joao@example.com"})
      certificate_fixture(scope, participant, %{status: :ready, emailed_at: nil})
      certificate_fixture(scope, other, %{status: :failed, email_status: :failed})

      filters = %{"batch_id" => batch.id}

      assert Certificates.participant_ids(scope, filters, :not_sent) == [participant.id]
      assert Certificates.participant_ids(scope, filters, :error) == [other.id]
      assert Certificates.participant_ids(scope, filters, :not_generated) == []
      assert Certificates.selection_counts(scope, filters).all == 2
    end

    test "builds the selected summary", %{
      scope: scope,
      participant: participant
    } do
      certificate_fixture(scope, participant, %{
        emailed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      summary = Certificates.selection_summary(scope, [participant.id])

      assert summary.total == 1
      assert summary.regenerate == 1
      assert summary.sent == 1
    end
  end

  describe "batch stats" do
    test "counts certificates by state", %{
      scope: scope,
      batch: batch,
      participant: participant
    } do
      certificate_fixture(scope, participant, %{
        emailed_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      stats = Certificates.batch_stats(scope, batch.id)

      assert stats.total == 1
      assert stats.generated == 1
      assert stats.sent == 1
      assert stats.failed == 0
    end
  end

  describe "admin access" do
    import Certfy.AccountsFixtures, only: [admin_scope_fixture: 0]

    test "manages certificates owned by other users", %{
      scope: owner_scope,
      participant: participant
    } do
      Certificates.prepare_for_participants(owner_scope, [participant.id])
      admin = admin_scope_fixture()

      certificate = Certificates.get_certificate_for_participant(admin, participant.id)
      assert certificate.participant_id == participant.id

      assert Certificates.get_certificate!(admin, certificate.id).id == certificate.id
      assert %{total: 1} = Certificates.batch_stats(admin, participant.batch_id)
      assert %{total: 1} = Certificates.selection_summary(admin, [participant.id])
      assert Certificates.participant_ids(admin, %{}, :all) == [participant.id]
      assert %{selected: 1} = Certificates.prepare_for_participants(admin, [participant.id])
      assert %{selected: 1} = Certificates.send_emails_for_batch(admin, participant.batch_id)
    end
  end
end
