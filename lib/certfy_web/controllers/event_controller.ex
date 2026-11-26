defmodule CertfyWeb.EventController do
  use CertfyWeb, :controller

  alias Certfy.{Events, Storage}

  @template_content_type "application/vnd.openxmlformats-officedocument.presentationml.presentation"

  def download_template(conn, %{"id" => id}) do
    event = Events.get_event!(conn.assigns.current_scope, id)

    case event.template_path do
      nil ->
        conn
        |> put_flash(:error, "Este evento não tem template.")
        |> redirect(to: ~p"/events/#{event}")

      template_path ->
        case Storage.get_template(template_path) do
          {:ok, body} ->
            send_download(conn, {:binary, body},
              filename: download_filename(event),
              content_type: @template_content_type
            )

          {:error, _reason} ->
            conn
            |> put_flash(:error, "Não foi possível baixar o template.")
            |> redirect(to: ~p"/events/#{event}")
        end
    end
  end

  defp download_filename(event) do
    slug =
      event.name
      |> String.replace(~r/[^\p{L}\p{N}._-]+/u, "-")
      |> String.trim("-")

    "#{if slug == "", do: "template", else: slug}.pptx"
  end
end
