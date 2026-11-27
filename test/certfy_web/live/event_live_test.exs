defmodule CertfyWeb.EventLiveTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures
  import Certfy.CertificatesFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  setup :register_and_log_in_user

  defp create_event(%{scope: scope}) do
    event = event_fixture(scope)

    %{event: event}
  end

  describe "Index" do
    setup [:create_event]

    test "lists all events", %{conn: conn, event: event} do
      {:ok, _index_live, html} = live(conn, ~p"/events")

      assert html =~ "Eventos"
      assert html =~ event.name
      assert html =~ "Modelo"
    end

    test "filters events by query and template", %{conn: conn, scope: scope} do
      with_template =
        event_with_template(scope, %{name: "Encontro com template"})

      without_template = event_fixture(scope, %{name: "Encontro sem template"})

      {:ok, _lv, html} = live(conn, ~p"/events?template=no")
      assert html =~ without_template.name
      refute html =~ with_template.name

      {:ok, _lv, html} = live(conn, ~p"/events?q=com template")
      assert html =~ with_template.name
      refute html =~ without_template.name
    end

    test "saves new event from the modal", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/events")

      index_live |> element("button", "Novo evento") |> render_click()
      assert has_element?(index_live, "#event-modal")

      assert index_live
             |> form("#modal-event-form", event: @invalid_attrs)
             |> render_change() =~ "não pode ficar em branco"

      assert {:ok, show_live, _html} =
               index_live
               |> form("#modal-event-form", event: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn)

      html = render(show_live)
      assert html =~ "some name"
    end

    test "closes the new event modal", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/events")

      index_live |> element("button", "Novo evento") |> render_click()
      assert has_element?(index_live, "#event-modal")

      index_live |> element("#event-modal button[aria-label=Fechar]") |> render_click()
      refute has_element?(index_live, "#event-modal")
    end

    test "saves extra data", %{conn: conn, scope: scope} do
      {:ok, form_live, _html} = live(conn, ~p"/events/new")

      form_live
      |> element("#event-extra-data-add")
      |> render_click()

      form_live
      |> element("#event-form")
      |> render_change(%{
        "event" => %{"name" => "event with extra data"},
        "extra_data" => %{"0" => %{"key" => "sala", "value" => "A"}}
      })

      assert {:ok, _show_live, _html} =
               form_live
               |> form("#event-form")
               |> render_submit()
               |> follow_redirect(conn)

      event =
        scope
        |> Certfy.Events.list_events()
        |> Enum.find(&(&1.name == "event with extra data"))

      assert event.extra_data == %{"sala" => "A"}
    end

    test "updates event in listing", %{conn: conn, event: event} do
      {:ok, index_live, _html} = live(conn, ~p"/events")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#events-#{event.id} a", "Editar")
               |> render_click()
               |> follow_redirect(conn, ~p"/events/#{event}/edit")

      assert render(form_live) =~ "Editar evento"

      assert form_live
             |> form("#event-form", event: @invalid_attrs)
             |> render_change() =~ "não pode ficar em branco"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#event-form", event: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events")

      html = render(index_live)
      assert html =~ "Evento atualizado com sucesso."
      assert html =~ "some updated name"
    end

    test "deletes event in listing", %{conn: conn, event: event} do
      {:ok, index_live, _html} = live(conn, ~p"/events")

      assert index_live |> element("#events-#{event.id} button", "Excluir") |> render_click()
      refute has_element?(index_live, "#events-#{event.id}")
    end
  end

  describe "Show" do
    setup [:create_event]

    test "displays event", %{conn: conn, event: event} do
      {:ok, _show_live, html} = live(conn, ~p"/events/#{event}")

      assert html =~ "Evento"
      assert html =~ event.name
    end

    test "updates event and returns to show", %{conn: conn, event: event} do
      {:ok, show_live, _html} = live(conn, ~p"/events/#{event}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Editar")
               |> render_click()
               |> follow_redirect(conn, ~p"/events/#{event}/edit?return_to=show")

      assert render(form_live) =~ "Editar evento"

      assert form_live
             |> form("#event-form", event: @invalid_attrs)
             |> render_change() =~ "não pode ficar em branco"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#event-form", event: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events/#{event}")

      html = render(show_live)
      assert html =~ "Evento atualizado com sucesso."
      assert html =~ "some updated name"
    end

    test "shows extra data", %{conn: conn, scope: scope} do
      event = event_fixture(scope, %{extra_data: %{"sala" => "Auditório"}})

      {:ok, _show_live, html} = live(conn, ~p"/events/#{event}")

      assert html =~ "Dados adicionais"
      assert html =~ "sala"
      assert html =~ "Auditório"
    end

    test "shows the event template", %{conn: conn, scope: scope} do
      event = event_with_template(scope)

      {:ok, _show_live, html} = live(conn, ~p"/events/#{event}")

      assert html =~ "Enviado"
      assert html =~ "Gerenciar modelo"
    end

    test "opens the new event modal from the URL parameter", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/events?novo=1")

      assert has_element?(index_live, "#event-modal")

      index_live |> element("#event-modal button[aria-label=Fechar]") |> render_click()
      refute has_element?(index_live, "#event-modal")
      assert_patch(index_live, ~p"/events?sort=updated")
    end

    test "creates a batch from the modal", %{conn: conn, scope: scope, event: event} do
      {:ok, show_live, _html} = live(conn, ~p"/events/#{event}")

      show_live |> element("button", "Novo lote") |> render_click()
      assert has_element?(show_live, "#batch-modal")

      assert show_live
             |> form("#modal-batch-form", batch: %{name: ""})
             |> render_change() =~ "não pode ficar em branco"

      html = show_live |> form("#modal-batch-form", batch: %{name: "Turma A"}) |> render_submit()

      assert html =~ "Lote Turma A criado."
      refute has_element?(show_live, "#batch-modal")
      assert Enum.any?(Certfy.Events.list_batches(scope, event), &(&1.name == "Turma A"))
    end

    test "lets an admin open an event owned by another user", %{conn: conn} do
      owner_scope = Certfy.AccountsFixtures.user_scope_fixture()
      event = event_fixture(owner_scope, %{name: "Evento de outro usuário"})
      admin = Certfy.AccountsFixtures.admin_fixture()

      {:ok, _show_live, html} = conn |> log_in_user(admin) |> live(~p"/events/#{event}")

      assert html =~ "Evento de outro usuário"
    end
  end
end
