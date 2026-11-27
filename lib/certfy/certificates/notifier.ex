defmodule Certfy.Certificates.Notifier do
  @moduledoc """
  Certificate e-mail with the PDF attached.
  """

  import Swoosh.Email

  alias Certfy.Mailer
  alias Certfy.Certificates.Certificate

  def deliver(%Certificate{} = certificate, pdf) do
    email = build(certificate, pdf)
    Mailer.deliver(email)
  end

  def build(%Certificate{} = certificate, pdf) do
    participant = certificate.participant
    event = certificate.event
    config = Application.get_env(:certfy, :certificates, [])
    from_email = Keyword.get(config, :from_email, "no-reply@certfy.local")
    from_name = Keyword.get(config, :from_name, "Certfy")

    attachment =
      Swoosh.Attachment.new({:data, pdf},
        filename: attachment_filename(certificate),
        content_type: "application/pdf"
      )

    new()
    |> to({participant.name, participant.email})
    |> from({from_name, from_email})
    |> subject("Seu certificado — #{event.name}")
    |> text_body(text_body(certificate))
    |> html_body(html_body(certificate))
    |> attachment(attachment)
  end

  @doc """
  Friendly attachment filename: `Certificado - Maria - Seminário 2026.pdf`.
  """
  def attachment_filename(%Certificate{} = certificate) do
    participant = certificate.participant.name || "Participante"
    event = certificate.event.name || "Evento"

    filename =
      "Certificado - #{participant} - #{event}.pdf"
      |> String.replace(~r/[\\\/:*?"<>|\x00-\x1F]/u, "")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()
      |> String.slice(0, 120)

    if String.ends_with?(filename, ".pdf"), do: filename, else: filename <> ".pdf"
  end

  defp text_body(certificate) do
    """
    Olá, #{certificate.participant.name}.

    Seu certificado do evento #{certificate.event.name} está anexado a este e-mail.
    Código de validação: #{certificate.code}

    Para validar, acesse #{validation_url(certificate)}.
    """
  end

  defp html_body(certificate) do
    name = escape(certificate.participant.name)
    event = escape(certificate.event.name)
    code = escape(certificate.code)
    url = validation_url(certificate)

    """
    <p>Olá, #{name}.</p>
    <p>Seu certificado do evento <strong>#{event}</strong> está anexado a este e-mail.</p>
    <p>Código de validação: <strong>#{code}</strong></p>
    <p><a href="#{escape(url)}">Validar certificado</a></p>
    """
  end

  defp validation_url(certificate) do
    CertfyWeb.Endpoint.url() <> "/validar/" <> certificate.code
  end

  defp escape(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
