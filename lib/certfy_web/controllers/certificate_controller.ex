defmodule CertfyWeb.CertificateController do
  use CertfyWeb, :controller

  alias Certfy.Certificates
  alias Certfy.Certificates.Notifier
  alias Certfy.Storage

  def validate(conn, %{"code" => code}) do
    render_validation(conn, code)
  end

  def validate(conn, params) do
    render_validation(conn, params["codigo"])
  end

  def download(conn, %{"id" => id}) do
    certificate = Certificates.get_certificate_for_download(conn.assigns.current_scope, id)

    cond do
      certificate.status != :ready or is_nil(certificate.pdf_path) ->
        conn
        |> put_flash(:error, "O certificado ainda não está pronto.")
        |> redirect(to: ~p"/participants/#{certificate.participant_id}")

      true ->
        case Storage.get_object(certificate.pdf_path) do
          {:ok, pdf} ->
            send_download(conn, {:binary, pdf},
              filename: Notifier.attachment_filename(certificate),
              content_type: "application/pdf"
            )

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Não foi possível baixar o certificado.")
            |> redirect(to: ~p"/participants/#{certificate.participant_id}")
        end
    end
  end

  defp render_validation(conn, code) do
    certificate =
      if is_binary(code) and String.trim(code) != "" do
        Certificates.get_certificate_by_code(code)
      end

    conn
    |> assign(:page_title, "Validar certificado")
    |> assign(:flash, %{})
    |> render(:validate, certificate: certificate, code: code || "")
  end
end
