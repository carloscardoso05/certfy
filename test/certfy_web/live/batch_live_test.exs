defmodule CertfyWeb.BatchLiveTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures

  @create_attrs %{name: "some name", extra_data: %{}}
  @update_attrs %{name: "some updated name", extra_data: %{}}
  @invalid_attrs %{name: nil}

  setup :register_and_log_in_user

  defp create_batch(%{scope: scope}) do
    event = event_fixture(scope)
    batch = batch_fixture(scope, event)

    %{event: event, batch: batch}
  end

  describe "Index" do
    setup [:create_batch]

    test "lists all batches", %{conn: conn, event: event, batch: batch} do
      {:ok, _index_live, html} = live(conn, ~p"/batches")

      assert html =~ "Lotes"
      assert html =~ batch.name
      assert html =~ event.name
    end

    test "does not list batches from another user", %{conn: conn} do
      other_scope = Certfy.AccountsFixtures.user_scope_fixture()
      other_event = event_fixture(other_scope)
      other_batch = batch_fixture(other_scope, other_event)

      {:ok, _index_live, html} = live(conn, ~p"/batches")

      refute html =~ other_batch.name
    end

    test "saves new batch", %{conn: conn, event: event} do
      {:ok, index_live, _html} = live(conn, ~p"/batches")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Novo lote")
               |> render_click()
               |> follow_redirect(conn, ~p"/batches/new")

      assert render(form_live) =~ "Novo lote"

      assert form_live
             |> form("#batch-form", batch: @invalid_attrs)
             |> render_change() =~ "não pode ficar em branco"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#batch-form", batch: Map.put(@create_attrs, :event_id, event.id))
               |> render_submit()
               |> follow_redirect(conn)

      html = render(show_live)
      assert html =~ "Lote criado com sucesso."
      assert html =~ "some name"
    end

    test "saves extra data", %{conn: conn, scope: scope, event: event} do
      {:ok, index_live, _html} = live(conn, ~p"/batches")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Novo lote")
               |> render_click()
               |> follow_redirect(conn, ~p"/batches/new")

      form_live |> element("#batch-extra-data-add") |> render_click()

      form_live
      |> element("#batch-form")
      |> render_change(%{
        "batch" => %{"name" => "batch with extra", "event_id" => to_string(event.id)},
        "extra_data" => %{"0" => %{"key" => "turno", "value" => "manhã"}}
      })

      assert {:ok, _show_live, _html} =
               form_live
               |> form("#batch-form")
               |> render_submit()
               |> follow_redirect(conn)

      batch =
        scope
        |> Certfy.Events.list_batches()
        |> Enum.find(&(&1.name == "batch with extra"))

      assert batch.extra_data == %{"turno" => "manhã"}
    end

    test "updates batch in listing", %{conn: conn, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/batches")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#batches-#{batch.id} a", "Editar")
               |> render_click()
               |> follow_redirect(conn, ~p"/batches/#{batch}/edit")

      assert render(form_live) =~ "Editar lote"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#batch-form", batch: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/batches")

      html = render(index_live)
      assert html =~ "Lote atualizado com sucesso."
      assert html =~ "some updated name"
    end

    test "pre-selects the event from the query param", %{conn: conn, event: event} do
      {:ok, form_live, _html} = live(conn, ~p"/batches/new?event_id=#{event.id}")

      assert has_element?(form_live, "#batch_event_id[role=combobox]")
      assert has_element?(form_live, "#batch_event_id[title='#{event.name}']")
      assert has_element?(form_live, "#batch_event_id-native option[selected]", event.name)
    end

    test "deletes batch in listing", %{conn: conn, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/batches")

      assert index_live |> element("#batches-#{batch.id} button", "Excluir") |> render_click()
      refute has_element?(index_live, "#batches-#{batch.id}")
    end
  end

  describe "Show" do
    setup [:create_batch]

    test "displays batch", %{conn: conn, event: event, batch: batch} do
      {:ok, _show_live, html} = live(conn, ~p"/batches/#{batch}")

      assert html =~ batch.name
      assert html =~ event.name
    end

    test "shows extra data", %{conn: conn, scope: scope, event: event} do
      batch = batch_fixture(scope, event, %{extra_data: %{"turno" => "Manhã"}})

      {:ok, _show_live, html} = live(conn, ~p"/batches/#{batch}")

      assert html =~ "Dados adicionais"
      assert html =~ "turno"
      assert html =~ "Manhã"
    end

    test "updates batch and returns to show", %{conn: conn, batch: batch} do
      {:ok, show_live, _html} = live(conn, ~p"/batches/#{batch}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Editar")
               |> render_click()
               |> follow_redirect(conn, ~p"/batches/#{batch}/edit?return_to=show")

      assert render(form_live) =~ "Editar lote"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#batch-form", batch: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/batches/#{batch}")

      html = render(show_live)
      assert html =~ "Lote atualizado com sucesso."
      assert html =~ "some updated name"
    end
  end
end
