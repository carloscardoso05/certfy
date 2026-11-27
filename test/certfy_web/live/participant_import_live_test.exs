defmodule CertfyWeb.ParticipantLive.ImportTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures
  import Certfy.ImportsFixtures

  alias Certfy.Events

  setup :register_and_log_in_user

  setup %{scope: scope} do
    event = event_fixture(scope)
    batch = batch_fixture(scope, event)

    %{batch: batch}
  end

  test "imports every valid CSV row into the batch", %{
    conn: conn,
    scope: scope,
    batch: batch
  } do
    content =
      csv([
        ["Nome", "E-mail", "Cidade"],
        ["Maria Silva", "maria@example.com", "Fortaleza"],
        ["João Souza", "invalido", "Recife"]
      ])

    {:ok, lv, html} = live(conn, ~p"/participants/import?batch_id=#{batch.id}")

    assert html =~ "Importar participantes"
    assert has_element?(lv, "#import-upload-form")
    assert render(lv) =~ ~s(phx-change="validate_upload")

    upload =
      file_input(lv, "#import-upload-form", :planilha, [%{name: "lista.csv", content: content}])

    assert render_upload(upload, "lista.csv") =~ "lista.csv"

    html = lv |> element("#import-upload-form") |> render_submit()

    assert html =~ "2 linha(s) · 2 pronta(s)"
    assert html =~ "1 e-mail(s) inválido(s) removido(s)"
    assert html =~ "Maria Silva"
    assert html =~ "Cidade"

    html = lv |> element("button", "Importar 2 participante(s)") |> render_click()

    assert html =~ "Importação concluída"
    assert html =~ batch.name

    participants = Events.list_participants(scope, batch)

    assert length(participants) == 2

    maria = Enum.find(participants, &(&1.name == "Maria Silva"))
    assert maria.email == "maria@example.com"
    assert maria.extra_data == %{"Cidade" => "Fortaleza"}

    joao = Enum.find(participants, &(&1.name == "João Souza"))
    assert joao.email == nil
  end

  test "imports XLSX files and detects columns from values", %{
    conn: conn,
    scope: scope,
    batch: batch
  } do
    content =
      xlsx([
        ["Maria Silva", "maria@example.com"],
        ["João Souza", "joao@example.com"]
      ])

    {:ok, lv, _html} = live(conn, ~p"/participants/import?batch_id=#{batch.id}")

    upload =
      file_input(lv, "#import-upload-form", :planilha, [%{name: "lista.xlsx", content: content}])

    assert render_upload(upload, "lista.xlsx") =~ "lista.xlsx"

    html = lv |> element("#import-upload-form") |> render_submit()

    assert html =~ "2 pronta(s)"
    assert html =~ "Maria Silva"
    assert html =~ "maria@example.com"

    lv |> element("button", "Importar 2 participante(s)") |> render_click()

    assert length(Events.list_participants(scope, batch)) == 2
  end

  test "adjusts the extra-data key before importing", %{conn: conn, scope: scope, batch: batch} do
    content =
      csv([
        ["Nome", "Contato", "Cidade"],
        ["Maria Silva", "maria@example.com", "Fortaleza"]
      ])

    {:ok, lv, _html} = live(conn, ~p"/participants/import?batch_id=#{batch.id}")

    upload =
      file_input(lv, "#import-upload-form", :planilha, [%{name: "lista.csv", content: content}])

    render_upload(upload, "lista.csv")
    lv |> element("#import-upload-form") |> render_submit()

    lv
    |> element("#mapping-form")
    |> render_change(%{
      "mapping" => %{
        "1" => %{"kind" => "email", "key" => "Contato"},
        "2" => %{"kind" => "extra", "key" => "Sala"}
      }
    })

    lv |> element("button", "Importar 1 participante(s)") |> render_click()

    assert [participant] = Events.list_participants(scope, batch)
    assert participant.email == "maria@example.com"
    assert participant.extra_data == %{"Sala" => "Fortaleza"}
  end

  test "lets the user choose whether the first row is a header", %{
    conn: conn,
    scope: scope,
    batch: batch
  } do
    content =
      xlsx([
        ["Maria Silva", "maria@gmail.com"],
        ["João Souza", "joao@gmail.com"]
      ])

    {:ok, lv, _html} = live(conn, ~p"/participants/import?batch_id=#{batch.id}")

    upload =
      file_input(lv, "#import-upload-form", :planilha, [%{name: "lista.xlsx", content: content}])

    render_upload(upload, "lista.xlsx")

    html = lv |> element("#import-upload-form") |> render_submit()

    assert html =~ "2 pronta(s)"
    assert has_element?(lv, "#header-form")

    html = lv |> element("#header-form") |> render_change(%{"header" => "true"})
    assert html =~ "1 pronta(s)"

    html = lv |> element("#header-form") |> render_change(%{"header" => "false"})
    assert html =~ "2 pronta(s)"

    lv |> element("button", "Importar 2 participante(s)") |> render_click()

    names =
      scope
      |> Events.list_participants(batch)
      |> Enum.map(& &1.name)
      |> Enum.sort()

    assert names == ["João Souza", "Maria Silva"]
  end

  test "requires a batch before analyzing", %{conn: conn, scope: scope, batch: batch} do
    {:ok, lv, html} = live(conn, ~p"/participants/import")

    assert html =~ "Selecione um lote antes de enviar a planilha."
    assert has_element?(lv, "#import-upload-form button[disabled]")

    html =
      lv
      |> element("#import-batch-form")
      |> render_change(%{"batch_id" => to_string(batch.id)})

    refute html =~ "Selecione um lote antes de enviar a planilha."
    assert has_element?(lv, "#import-upload-form button:not([disabled])")
    assert Events.list_batches_with_events(scope) != []
  end

  test "blocks import when extra column keys are duplicated", %{
    conn: conn,
    batch: batch
  } do
    content =
      csv([
        ["Nome", "Cidade", "Cidade"],
        ["Maria Silva", "Fortaleza", "Recife"]
      ])

    {:ok, lv, _html} = live(conn, ~p"/participants/import?batch_id=#{batch.id}")

    upload =
      file_input(lv, "#import-upload-form", :planilha, [%{name: "lista.csv", content: content}])

    render_upload(upload, "lista.csv")

    html = lv |> element("#import-upload-form") |> render_submit()

    assert html =~ "Há chaves de dados adicionais repetidas."
    assert has_element?(lv, "button[phx-click=import][disabled]")
  end

  test "reports unreadable files", %{conn: conn, batch: batch} do
    {:ok, lv, _html} = live(conn, ~p"/participants/import?batch_id=#{batch.id}")

    upload =
      file_input(lv, "#import-upload-form", :planilha, [
        %{name: "lista.xlsx", content: "not a zip"}
      ])

    render_upload(upload, "lista.xlsx")

    html = lv |> element("#import-upload-form") |> render_submit()

    assert html =~ "Não foi possível ler o arquivo XLSX."
  end
end
