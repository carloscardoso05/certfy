defmodule CertfyWeb.NavigationTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures
  import Certfy.CertificatesFixtures

  setup :register_and_log_in_user

  test "event page shows contextual tabs and the next step", %{conn: conn, scope: scope} do
    event = event_with_template(scope, %{name: "Congresso"})
    batch = batch_fixture(scope, event, %{name: "Turma A"})
    participant_fixture(scope, batch, %{name: "Maria"})

    {:ok, lv, html} = live(conn, ~p"/events/#{event}")

    assert html =~ "Congresso"
    assert has_element?(lv, "nav[aria-label='Navegação do evento']")
    assert has_element?(lv, "a[href='/events/#{event.id}'][aria-current='page']")
    assert has_element?(lv, "a[href='/batches?event_id=#{event.id}']")
    assert has_element?(lv, "a[href='/participants?event_id=#{event.id}']")
    assert has_element?(lv, "a[href='/events/#{event.id}/template']")
    assert html =~ "Gere os certificados"
  end

  test "event without template points to the model", %{conn: conn, scope: scope} do
    event = event_fixture(scope)

    {:ok, _lv, html} = live(conn, ~p"/events/#{event}")

    assert html =~ "Envie o modelo do certificado"
    assert html =~ "Enviar modelo"
  end

  test "batch page shows tabs, actions and the missing model warning", %{
    conn: conn,
    scope: scope
  } do
    event = event_fixture(scope, %{name: "Sem modelo"})
    batch = batch_fixture(scope, event, %{name: "Turma B"})

    {:ok, lv, html} = live(conn, ~p"/batches/#{batch}")

    assert has_element?(lv, "nav[aria-label='Navegação do lote']")
    assert has_element?(lv, "a[href='/participants?batch_id=#{batch.id}']")
    assert has_element?(lv, "a[href='/participants/new?batch_id=#{batch.id}']")
    assert has_element?(lv, "a[href='/participants/import?batch_id=#{batch.id}']")
    assert html =~ "O evento ainda não tem modelo de certificado"
  end

  test "participant list inside a batch shows context and hides redundant filters", %{
    conn: conn,
    scope: scope
  } do
    event = event_fixture(scope, %{name: "Evento A"})
    batch = batch_fixture(scope, event, %{name: "Turma A"})
    participant = participant_fixture(scope, batch, %{name: "Maria"})
    other_batch = batch_fixture(scope, event, %{name: "Turma B"})
    other = participant_fixture(scope, other_batch, %{name: "João"})

    {:ok, lv, html} = live(conn, ~p"/participants?batch_id=#{batch.id}")

    assert html =~ "Participantes do lote Turma A"
    assert has_element?(lv, "#participants-#{participant.id}")
    refute has_element?(lv, "#participants-#{other.id}")
    refute has_element?(lv, "#participant-filter-event")
    refute has_element?(lv, "#participant-filter-batch")
    assert has_element?(lv, "a[href='/participants/new?batch_id=#{batch.id}']")
    assert has_element?(lv, "a[href='/participants/import?batch_id=#{batch.id}']")
  end

  test "participant list inside an event keeps the batch filter", %{conn: conn, scope: scope} do
    event = event_fixture(scope, %{name: "Evento B"})
    _batch = batch_fixture(scope, event)

    {:ok, lv, html} = live(conn, ~p"/participants?event_id=#{event.id}")

    assert html =~ "Participantes do evento Evento B"
    refute has_element?(lv, "#participant-filter-event")
    assert has_element?(lv, "#participant-filter-batch")
  end

  test "batch list inside an event shows context and hides the event filter", %{
    conn: conn,
    scope: scope
  } do
    event = event_fixture(scope, %{name: "Evento C"})
    batch = batch_fixture(scope, event, %{name: "Turma C"})

    {:ok, lv, html} = live(conn, ~p"/batches?event_id=#{event.id}")

    assert html =~ "Lotes de Evento C"
    assert has_element?(lv, "#batches-#{batch.id}")
    refute has_element?(lv, "#batch-filter-event")
    assert has_element?(lv, "a[href='/events/#{event.id}/template']")
  end

  test "global participant list keeps all filters", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/participants")

    assert html =~ "Participantes"
    assert has_element?(lv, "#participant-filter-event")
    assert has_element?(lv, "#participant-filter-batch")
  end
end
