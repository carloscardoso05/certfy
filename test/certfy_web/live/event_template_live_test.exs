defmodule CertfyWeb.EventTemplateLiveTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures
  import Certfy.CertificatesFixtures

  alias Certfy.Events

  setup :register_and_log_in_user

  defp upload(view, path, name) do
    upload =
      file_input(view, "#template-upload-form", :template, [
        %{
          name: name,
          content: File.read!(path),
          size: File.stat!(path).size,
          type: "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        }
      ])

    render_upload(upload, name)
  end

  test "uploads a valid template and shows its tags", %{conn: conn, scope: scope} do
    event = event_fixture(scope)

    {:ok, view, html} = live(conn, ~p"/events/#{event}/template")
    assert html =~ "Arquivo do modelo"

    upload(view, "test/fixtures/certificate_template.pptx", "modelo.pptx")
    view |> element("#template-upload-form") |> render_submit()

    html = render(view)
    assert html =~ "Modelo enviado."
    assert html =~ "participant.name"
    assert html =~ "event.horas"

    event = Events.get_event!(scope, event.id)
    assert event.template_path =~ ~r{\Atemplates/}
    assert event.template_report["malformed"] == []
  end

  test "accepts a malformed template but shows the blocking warning", %{
    conn: conn,
    scope: scope
  } do
    event = event_fixture(scope)

    {:ok, view, _html} = live(conn, ~p"/events/#{event}/template")
    upload(view, "test/fixtures/certificate_template_invalid.pptx", "invalido.pptx")
    view |> element("#template-upload-form") |> render_submit()

    html = render(view)
    assert html =~ "tags malformadas"
    assert html =~ "A geração e a pré-visualização com dados ficam bloqueadas"

    event = Events.get_event!(scope, event.id)
    assert event.template_report["malformed"] != []
  end

  test "shows catalog values and follows the participant selector", %{
    conn: conn,
    scope: scope
  } do
    event = event_with_template(scope)
    batch = batch_fixture(scope, event, %{extra_data: %{"Turno" => "Manhã"}})
    participant = participant_fixture(scope, batch, %{extra_data: %{"Empresa" => "Certfy"}})

    {:ok, view, html} = live(conn, ~p"/events/#{event}/template")

    assert html =~ "Tags que você pode usar"
    assert html =~ "{{batch.turno}}"
    assert html =~ "{{participant.empresa}}"
    assert html =~ "Certfy"

    view
    |> element("#participant-select-form")
    |> render_change(%{"participant_id" => participant.id})

    html = render(view)
    assert html =~ "Certfy"
    assert html =~ "Manhã"
  end

  test "removes the template", %{conn: conn, scope: scope} do
    event = event_with_template(scope)

    {:ok, view, _html} = live(conn, ~p"/events/#{event}/template")

    view |> element("button[phx-click=remove_template]") |> render_click()

    assert render(view) =~ "Modelo removido."
    assert is_nil(Events.get_event!(scope, event.id).template_path)
  end
end
