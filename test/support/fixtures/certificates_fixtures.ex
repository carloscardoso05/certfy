defmodule Certfy.CertificatesFixtures do
  @moduledoc """
  Test helpers for certificates and PPTX templates.
  """

  @fixture_path "test/fixtures/certificate_template.pptx"
  @invalid_fixture_path "test/fixtures/certificate_template_invalid.pptx"

  def pptx_binary, do: File.read!(@fixture_path)
  def invalid_pptx_binary, do: File.read!(@invalid_fixture_path)

  def pptx_report do
    {:ok, report} = Certfy.Certificates.Pptx.analyze(pptx_binary())
    report
  end

  def invalid_pptx_report do
    {:ok, report} = Certfy.Certificates.Pptx.analyze(invalid_pptx_binary())
    report
  end

  def template_path, do: "templates/test-template.pptx"

  def event_with_template(scope, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          template_path: template_path(),
          template_report: pptx_report()
        },
        attrs
      )

    Certfy.EventsFixtures.event_fixture(scope, attrs)
  end

  def certificate_fixture(scope, participant, attrs \\ %{}) do
    participant = Certfy.Repo.preload(participant, batch: :event)

    attrs =
      Enum.into(attrs, %{
        code: Certfy.Certificates.QR.code(),
        status: :ready,
        email_status: :pending,
        pdf_path: "certificates/#{scope.user.id}/#{participant.id}/v1.pdf",
        version: 1,
        snapshot: %{
          "participant.name" => participant.name,
          "event.name" => participant.batch.event.name,
          "batch.name" => participant.batch.name
        },
        warnings: []
      })

    %Certfy.Certificates.Certificate{
      user_id: scope.user.id,
      event_id: participant.batch.event_id,
      batch_id: participant.batch_id,
      participant_id: participant.id,
      generated_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
    |> Certfy.Certificates.Certificate.changeset(attrs)
    |> Certfy.Repo.insert!()
  end
end
