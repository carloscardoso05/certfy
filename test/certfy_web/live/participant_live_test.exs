defmodule CertfyWeb.ParticipantLiveTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures

  @create_attrs %{name: "some name", email: "some@email.com"}
  @update_attrs %{name: "some updated name", email: "some.updated@email.com"}
  @invalid_attrs %{name: nil, email: nil}

  setup :register_and_log_in_user

  defp create_participant(%{scope: scope}) do
    event = event_fixture(scope)
    batch = batch_fixture(scope, event)
    participant = participant_fixture(scope, batch)

    %{event: event, batch: batch, participant: participant}
  end

  describe "Index" do
    setup [:create_participant]

    test "lists all participants", %{
      conn: conn,
      event: event,
      batch: batch,
      participant: participant
    } do
      {:ok, _index_live, html} = live(conn, ~p"/participants")

      assert html =~ "Participantes"
      assert html =~ participant.name
      assert html =~ event.name
      assert html =~ batch.name
    end

    test "does not list participants from another user", %{conn: conn} do
      other_scope = Certfy.AccountsFixtures.user_scope_fixture()
      other_event = event_fixture(other_scope)
      other_batch = batch_fixture(other_scope, other_event)
      other_participant = participant_fixture(other_scope, other_batch, %{name: "other person"})

      {:ok, _index_live, html} = live(conn, ~p"/participants")

      refute html =~ other_participant.name
    end

    test "saves new participant", %{conn: conn, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/participants")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Novo participante")
               |> render_click()
               |> follow_redirect(conn, ~p"/participants/new")

      assert render(form_live) =~ "Novo participante"

      assert form_live
             |> form("#participant-form", participant: @invalid_attrs)
             |> render_change() =~ "não pode ficar em branco"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#participant-form",
                 participant: Map.put(@create_attrs, :batch_id, batch.id)
               )
               |> render_submit()
               |> follow_redirect(conn, ~p"/participants")

      html = render(index_live)
      assert html =~ "Participante criado com sucesso."
      assert html =~ "some name"
    end

    test "saves a participant without email", %{conn: conn, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/participants")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Novo participante")
               |> render_click()
               |> follow_redirect(conn, ~p"/participants/new")

      assert {:ok, index_live, _html} =
               form_live
               |> form("#participant-form",
                 participant: %{name: "sem email", email: "", batch_id: batch.id}
               )
               |> render_submit()
               |> follow_redirect(conn, ~p"/participants")

      html = render(index_live)
      assert html =~ "sem email"
    end

    test "saves extra data", %{conn: conn, scope: scope, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/participants")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "Novo participante")
               |> render_click()
               |> follow_redirect(conn, ~p"/participants/new")

      form_live |> element("#participant-extra-data-add") |> render_click()

      form_live
      |> element("#participant-form")
      |> render_change(%{
        "participant" => %{"name" => "participant with extra", "batch_id" => to_string(batch.id)},
        "extra_data" => %{"0" => %{"key" => "empresa", "value" => "Certfy"}}
      })

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#participant-form")
               |> render_submit()
               |> follow_redirect(conn, ~p"/participants")

      participant =
        scope
        |> Certfy.Events.list_participants(batch)
        |> Enum.find(&(&1.name == "participant with extra"))

      assert participant.extra_data == %{"empresa" => "Certfy"}
    end

    test "filters participants by event and batch", %{
      conn: conn,
      scope: scope,
      batch: batch,
      participant: participant
    } do
      other_event = event_fixture(scope, %{name: "Outro evento"})
      other_batch = batch_fixture(scope, other_event, %{name: "Outro lote"})
      other = participant_fixture(scope, other_batch, %{name: "Pessoa de outro lote"})

      {:ok, _lv, html} = live(conn, ~p"/participants?batch_id=#{batch.id}")
      assert html =~ batch.name
      refute html =~ other.name

      {:ok, lv, _html} = live(conn, ~p"/participants?event_id=#{other_event.id}")
      assert has_element?(lv, "#participants-#{other.id}")
      refute has_element?(lv, "#participants-#{participant.id}")
    end

    test "updates participant in listing", %{conn: conn, participant: participant} do
      {:ok, index_live, _html} = live(conn, ~p"/participants")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#participants-#{participant.id} a", "Editar")
               |> render_click()
               |> follow_redirect(conn, ~p"/participants/#{participant}/edit")

      assert render(form_live) =~ "Editar participante"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#participant-form", participant: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/participants")

      html = render(index_live)
      assert html =~ "Participante atualizado com sucesso."
      assert html =~ "some updated name"
    end

    test "pre-selects the batch from the query param", %{conn: conn, event: event, batch: batch} do
      {:ok, form_live, _html} = live(conn, ~p"/participants/new?batch_id=#{batch.id}")

      assert has_element?(form_live, "#participant_batch_id[role=combobox]")

      assert has_element?(
               form_live,
               "#participant_batch_id[title='#{event.name} — #{batch.name}']"
             )

      assert has_element?(form_live, "#participant_batch_id-native option[selected]", batch.name)
    end

    test "deletes participant in listing", %{conn: conn, participant: participant} do
      {:ok, index_live, _html} = live(conn, ~p"/participants")

      assert index_live
             |> element("#participants-#{participant.id} button", "Excluir")
             |> render_click()

      refute has_element?(index_live, "#participants-#{participant.id}")
    end
  end

  describe "Show" do
    setup [:create_participant]

    test "displays participant", %{
      conn: conn,
      event: event,
      batch: batch,
      participant: participant
    } do
      {:ok, _show_live, html} = live(conn, ~p"/participants/#{participant}")

      assert html =~ participant.name
      assert html =~ event.name
      assert html =~ batch.name
    end

    test "shows extra data", %{conn: conn, scope: scope, batch: batch} do
      participant = participant_fixture(scope, batch, %{extra_data: %{"empresa" => "Certfy"}})

      {:ok, _show_live, html} = live(conn, ~p"/participants/#{participant}")

      assert html =~ "Dados adicionais"
      assert html =~ "empresa"
      assert html =~ "Certfy"
    end

    test "updates participant and returns to show", %{conn: conn, participant: participant} do
      {:ok, show_live, _html} = live(conn, ~p"/participants/#{participant}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Editar")
               |> render_click()
               |> follow_redirect(conn, ~p"/participants/#{participant}/edit?return_to=show")

      assert render(form_live) =~ "Editar participante"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#participant-form", participant: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/participants/#{participant}")

      html = render(show_live)
      assert html =~ "Participante atualizado com sucesso."
      assert html =~ "some updated name"
    end
  end
end
