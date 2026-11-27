defmodule CertfyWeb.TemplateController do
  use CertfyWeb, :controller

  alias Certfy.{Certificates, Events, Storage}
  alias Certfy.Certificates.{PDF, Pptx, QR, Tags}

  def download(conn, %{"id" => id}) do
    event = Events.get_event!(conn.assigns.current_scope, id)

    case event.template_path do
      nil ->
        conn
        |> put_flash(:error, "Este evento não tem template.")
        |> redirect(to: ~p"/events/#{event}/template")

      path ->
        with {:ok, pptx} <- Storage.get_template(path) do
          send_download(conn, {:binary, pptx},
            filename: filename(event, "pptx"),
            content_type:
              "application/vnd.openxmlformats-officedocument.presentationml.presentation"
          )
        else
          _ ->
            conn
            |> put_flash(:error, "Não foi possível baixar o template.")
            |> redirect(to: ~p"/events/#{event}/template")
        end
    end
  end

  def preview(conn, params) do
    event = Events.get_event!(conn.assigns.current_scope, params["id"])

    cond do
      is_nil(event.template_path) ->
        conn
        |> send_resp(404, "Este evento não tem template.")
        |> halt()

      params["participant_id"] || params["sample"] ->
        render_data_preview(conn, event, params)

      true ->
        render_static_preview(conn, event)
    end
  end

  defp render_static_preview(conn, event) do
    cache_path = event.template_path <> ".preview.pdf"

    case Storage.get_object(cache_path) do
      {:ok, pdf} ->
        send_inline(conn, pdf, filename(event, "pdf"))

      {:error, _} ->
        with {:ok, pptx} <- Storage.get_template(event.template_path),
             {:ok, pdf} <- PDF.render(pptx),
             {:ok, _} <- Storage.put_object(cache_path, pdf, "application/pdf") do
          send_inline(conn, pdf, filename(event, "pdf"))
        else
          _ -> conn |> send_resp(500, "Não foi possível pré-visualizar o template.") |> halt()
        end
    end
  end

  defp render_data_preview(conn, event, params) do
    if Certificates.malformed_template?(event) do
      conn
      |> send_resp(422, "Corrija as tags malformadas antes de visualizar com dados.")
      |> halt()
    else
      values = preview_values(conn.assigns.current_scope, event, params)
      code = "EXEMPLO123"

      with {:ok, qr_png} <- QR.png(code),
           {:ok, pptx} <- Storage.get_template(event.template_path),
           {:ok, merged, _warnings} <- Pptx.render(pptx, values, qr_png),
           {:ok, pdf} <- PDF.render(merged) do
        send_inline(conn, pdf, filename(event, "preview.pdf"))
      else
        {:error, {:malformed_tags, _}} ->
          conn
          |> send_resp(422, "O template possui tags malformadas.")
          |> halt()

        _ ->
          conn
          |> send_resp(500, "Não foi possível gerar a pré-visualização.")
          |> halt()
      end
    end
  end

  defp preview_values(scope, event, params) do
    code = "EXEMPLO123"

    case params["participant_id"] do
      nil ->
        sample_values(event, code)
        |> put_extra("evento", event.extra_data)

      participant_id ->
        participant = Events.get_participant_with_context!(scope, participant_id)
        batch = participant.batch

        if batch.event_id == event.id do
          Tags.build(participant, batch, event, %{code: code})
        else
          sample_values(event, code)
        end
    end
  end

  defp sample_values(event, code) do
    %{
      "evento.nome" => event.name,
      "lote.nome" => "Lote de exemplo",
      "participante.nome" => "Maria da Silva",
      "participante.email" => "maria@exemplo.com",
      "certificado.codigo" => code,
      "certificado.data_emissao" => Calendar.strftime(Date.utc_today(), "%d/%m/%Y")
    }
  end

  defp put_extra(values, prefix, extra_data) do
    Enum.reduce(extra_data || %{}, values, fn {key, value}, acc ->
      key = Tags.normalize_key(key)
      if key == "", do: acc, else: Map.put(acc, "#{prefix}.#{key}", to_string(value))
    end)
  end

  defp send_inline(conn, pdf, filename) do
    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("content-disposition", ~s(inline; filename="#{filename}"))
    |> send_resp(200, pdf)
  end

  defp filename(event, extension) do
    slug =
      event.name
      |> String.replace(~r/[^\p{L}\p{N}._-]+/u, "-")
      |> String.trim("-")

    "#{if slug == "", do: "template", else: slug}.#{extension}"
  end
end
