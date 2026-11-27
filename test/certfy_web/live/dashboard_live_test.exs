defmodule CertfyWeb.DashboardLiveTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures
  import Certfy.CertificatesFixtures

  setup :register_and_log_in_user

  test "shows onboarding when there are no events", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "Comece pelo seu primeiro evento"
    assert html =~ "Criar primeiro evento"
    assert html =~ "Um lote é uma turma, dia ou categoria"
  end

  test "shows summary and recent events", %{conn: conn, scope: scope} do
    event = event_with_template(scope, %{name: "Evento principal"})
    batch = batch_fixture(scope, event, %{name: "Turma A"})
    participant_fixture(scope, batch, %{name: "Maria"})

    {:ok, lv, html} = live(conn, ~p"/")

    assert has_element?(lv, "#recent-event-#{event.id}")
    assert html =~ "Evento principal"
    assert html =~ "Eventos recentes"
    assert html =~ "Gerados"
    assert html =~ "Enviados"
  end

  test "does not show data from another user", %{conn: conn} do
    other_scope = Certfy.AccountsFixtures.user_scope_fixture()
    other_event = event_fixture(other_scope, %{name: "Evento de outra pessoa"})

    {:ok, _lv, html} = live(conn, ~p"/")

    refute html =~ other_event.name
    assert html =~ "Comece pelo seu primeiro evento"
  end

  test "shows data from every user to an admin", %{conn: conn} do
    other_scope = Certfy.AccountsFixtures.user_scope_fixture()
    other_event = event_fixture(other_scope, %{name: "Evento de outra pessoa"})
    admin = Certfy.AccountsFixtures.admin_fixture()

    {:ok, _lv, html} = conn |> log_in_user(admin) |> live(~p"/")

    assert html =~ other_event.name
  end

  test "shows attention items for incomplete setups", %{conn: conn, scope: scope} do
    _event = event_fixture(scope, %{name: "Sem modelo"})

    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "Precisa de atenção"
    assert html =~ "sem modelo de certificado"
  end

  test "shows attention for a batch without participants", %{conn: conn, scope: scope} do
    event = event_with_template(scope, %{name: "Com modelo"})
    _batch = batch_fixture(scope, event)

    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "lote(s) ainda sem participantes"
  end

  test "shows attention for failed certificates", %{conn: conn, scope: scope} do
    event = event_with_template(scope)
    batch = batch_fixture(scope, event)
    participant = participant_fixture(scope, batch)
    certificate_fixture(scope, participant, %{status: :failed})

    {:ok, _lv, html} = live(conn, ~p"/")

    assert html =~ "certificado(s) com erro"
  end

  test "sidebar highlights Início and no longer lists Lotes", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/")

    assert has_element?(lv, "aside a[href='/']")
    refute has_element?(lv, "aside a[href='/batches']")
    assert has_element?(lv, "aside a[href='/participants']")
    assert has_element?(lv, "aside a[href='/como-funciona']")
  end

  test "renders the help page", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/como-funciona")

    assert html =~ "Como funciona"
    assert html =~ "O que é um lote?"
    assert html =~ "O que é o modelo do certificado?"
  end
end
