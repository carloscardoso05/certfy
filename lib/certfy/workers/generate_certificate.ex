defmodule Certfy.Workers.GenerateCertificate do
  @moduledoc """
  Renders a participant certificate from a PPTX template and stores the PDF.
  """

  use Oban.Worker,
    queue: :certificates,
    max_attempts: 3,
    unique: [
      period: 120,
      keys: [:certificate_id],
      states: [:available, :scheduled, :executing, :retryable]
    ]

  require Logger

  alias Certfy.Certificates
  alias Certfy.Certificates.{PDF, Pptx, QR, Tags}
  alias Certfy.Storage

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"certificate_id" => certificate_id, "version" => version}}) do
    case Certificates.get_certificate_with_context(certificate_id) do
      nil ->
        {:discard, :certificate_not_found}

      %{version: current} when current != version ->
        {:discard, :stale_certificate}

      certificate ->
        generate(certificate, version)
    end
  end

  defp generate(certificate, version) do
    event = certificate.participant.batch.event

    cond do
      is_nil(event.template_path) ->
        Certificates.mark_failed(certificate, "O evento não possui um modelo de certificado.")
        {:discard, :template_missing}

      Certificates.malformed_template?(event) ->
        Certificates.mark_failed(certificate, "O modelo possui tags malformadas.")
        {:discard, :malformed_template}

      true ->
        do_generate(certificate, version, event)
    end
  end

  defp do_generate(certificate, version, event) do
    {:ok, _} = Certificates.mark_processing(certificate)
    old_path = certificate.pdf_path

    values = Tags.build(certificate.participant, certificate.batch, event, certificate)
    {:ok, qr_png} = QR.png(certificate.code)
    key = Storage.certificate_key(certificate.user_id, certificate.participant_id, version + 1)

    with {:ok, pptx} <- Storage.get_template(event.template_path),
         {:ok, merged, warnings} <- Pptx.render(pptx, values, qr_png),
         {:ok, pdf} <- PDF.render(merged),
         {:ok, _key} <- Storage.put_object(key, pdf, "application/pdf") do
      {:ok, certificate} =
        Certificates.mark_ready(certificate, %{
          status: :ready,
          pdf_path: key,
          page_count: event.template_report["slides"],
          version: version + 1,
          snapshot: values,
          warnings: warnings,
          generated_at: now(),
          error: nil,
          email_status:
            if(certificate.participant.email in [nil, ""], do: :skipped, else: :pending)
        })

      delete_old_pdf(old_path, key)

      {:ok, %{certificate_id: certificate.id, version: certificate.version}}
    else
      {:error, reason} ->
        Logger.error("Certificate #{certificate.id} failed: #{inspect(reason)}")
        Certificates.mark_failed(certificate, error_message(reason))
        {:error, reason}
    end
  end

  defp delete_old_pdf(old_path, new_path) when old_path not in [nil, new_path] do
    Storage.delete_object(old_path)
  end

  defp delete_old_pdf(_old_path, _new_path), do: :ok

  defp error_message({:malformed_tags, tags}) do
    "O modelo possui tags malformadas: #{Enum.join(tags, ", ")}"
  end

  defp error_message({:http_error, status, _body}), do: "Falha ao gerar o PDF (HTTP #{status})."
  defp error_message(:invalid_zip), do: "O modelo não é um arquivo .pptx válido."
  defp error_message(:no_slides), do: "O modelo não possui slides."
  defp error_message(reason), do: "Falha ao gerar o certificado: #{inspect(reason)}"

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
