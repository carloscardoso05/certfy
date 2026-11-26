defmodule CertfyWeb.EventLiveTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures

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
      assert html =~ "Tem template?"
    end

    test "saves new event", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/events")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Novo evento")
               |> render_click()
               |> follow_redirect(conn, ~p"/events/new")

      assert render(form_live) =~ "Novo evento"

      assert form_live
             |> form("#event-form", event: @invalid_attrs)
             |> render_change() =~ "não pode ficar em branco"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#event-form", event: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events")

      html = render(index_live)
      assert html =~ "Evento criado com sucesso."
      assert html =~ "some name"
    end

    test "saves a template file", %{conn: conn, scope: scope} do
      {:ok, index_live, _html} = live(conn, ~p"/events")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Novo evento")
               |> render_click()
               |> follow_redirect(conn, ~p"/events/new")

      content = "template content"

      upload =
        file_input(form_live, "#event-form", :template, [
          %{
            last_modified: 1_594_171_879_000,
            name: "template.pptx",
            content: content,
            size: byte_size(content),
            type: "application/vnd.openxmlformats-officedocument.presentationml.presentation"
          }
        ])

      assert render_upload(upload, "template.pptx") =~ "100%"

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#event-form", event: %{name: "event with template"})
               |> render_submit()
               |> follow_redirect(conn, ~p"/events")

      event =
        scope
        |> Certfy.Events.list_events()
        |> Enum.find(&(&1.name == "event with template"))

      assert event.template_path =~ ~r{\Atemplates/[A-Za-z0-9_-]+\.pptx\z}
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

      assert index_live |> element("#events-#{event.id} a", "Excluir") |> render_click()
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
  end
end
