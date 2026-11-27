defmodule Certfy.Workers.SendCertificateEmail do
  @moduledoc """
  Sends the certificate PDF to the participant.
  """

  use Oban.Worker,
    queue: :emails,
    max_attempts: 3,
    unique: [
      period: 60,
      keys: [:certificate_id],
      states: [:available, :scheduled, :executing, :retryable]
    ]

  alias Certfy.Certificates
  alias Certfy.Certificates.Notifier
  alias Certfy.Storage

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"certificate_id" => certificate_id, "version" => version}}) do
    certificate = Certificates.get_certificate_with_context(certificate_id)
    config = Application.get_env(:certfy, :certificates, [])
    max_bytes = Keyword.get(config, :max_attachment_bytes, 15_000_000)

    cond do
      is_nil(certificate) ->
        {:discard, :certificate_not_found}

      certificate.version != version ->
        {:discard, :stale_certificate}

      certificate.status != :ready or is_nil(certificate.pdf_path) ->
        {:discard, :certificate_not_ready}

      certificate.participant.email in [nil, ""] ->
        Certificates.mark_email_skipped(certificate)
        {:discard, :participant_without_email}

      true ->
        send_email(certificate, max_bytes)
    end
  end

  defp send_email(certificate, max_bytes) do
    with {:ok, pdf} <- Storage.get_object(certificate.pdf_path),
         :ok <- check_size(pdf, max_bytes),
         {:ok, _metadata} <- Notifier.deliver(certificate, pdf) do
      Certificates.mark_email_sent(certificate)
      {:ok, %{certificate_id: certificate.id}}
    else
      {:error, :attachment_too_large} ->
        Certificates.mark_email_failed(certificate, "O PDF excede o limite de anexo de e-mail.")
        {:discard, :attachment_too_large}

      {:error, reason} ->
        Certificates.mark_email_failed(certificate, inspect(reason))
        {:error, reason}
    end
  end

  defp check_size(pdf, max_bytes) when byte_size(pdf) <= max_bytes, do: :ok
  defp check_size(_pdf, _max_bytes), do: {:error, :attachment_too_large}
end
