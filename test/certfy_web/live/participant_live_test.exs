defmodule CertfyWeb.ParticipantLiveTest do
  use CertfyWeb.ConnCase

  import Phoenix.LiveViewTest
  import Certfy.EventsFixtures

  @create_attrs %{name: "some name", email: "some@email.com", extra_data: %{}}
  @update_attrs %{name: "some updated name", email: "some.updated@email.com", extra_data: %{}}
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
      {:ok, _index_live, html} = live(conn, ~p"/events/#{event}/batches/#{batch}/participants")

      assert html =~ "Listing Participants"
      assert html =~ participant.name
    end

    test "does not list participants from another batch", %{
      conn: conn,
      scope: scope,
      event: event,
      batch: batch
    } do
      other_event = event_fixture(scope)
      other_batch = batch_fixture(scope, other_event)
      other_participant = participant_fixture(scope, other_batch, %{name: "other participant"})

      {:ok, _index_live, html} =
        live(conn, ~p"/events/#{event}/batches/#{batch}/participants")

      refute html =~ other_participant.name
    end

    test "saves new participant", %{conn: conn, event: event, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{event}/batches/#{batch}/participants")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Participant")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/events/#{event}/batches/#{batch}/participants/new"
               )

      assert render(form_live) =~ "New Participant"

      assert form_live
             |> form("#participant-form", participant: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#participant-form", participant: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events/#{event}/batches/#{batch}/participants")

      html = render(index_live)
      assert html =~ "Participant created successfully"
      assert html =~ "some name"
    end

    test "updates participant in listing", %{
      conn: conn,
      event: event,
      batch: batch,
      participant: participant
    } do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{event}/batches/#{batch}/participants")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#participants-#{participant.id} a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/events/#{event}/batches/#{batch}/participants/#{participant}/edit"
               )

      assert render(form_live) =~ "Edit Participant"

      assert form_live
             |> form("#participant-form", participant: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#participant-form", participant: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events/#{event}/batches/#{batch}/participants")

      html = render(index_live)
      assert html =~ "Participant updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes participant in listing", %{
      conn: conn,
      event: event,
      batch: batch,
      participant: participant
    } do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{event}/batches/#{batch}/participants")

      assert index_live
             |> element("#participants-#{participant.id} a", "Delete")
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
      {:ok, _show_live, html} =
        live(conn, ~p"/events/#{event}/batches/#{batch}/participants/#{participant}")

      assert html =~ "Show Participant"
      assert html =~ participant.name
    end

    test "updates participant and returns to show", %{
      conn: conn,
      event: event,
      batch: batch,
      participant: participant
    } do
      {:ok, show_live, _html} =
        live(conn, ~p"/events/#{event}/batches/#{batch}/participants/#{participant}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/events/#{event}/batches/#{batch}/participants/#{participant}/edit?return_to=show"
               )

      assert render(form_live) =~ "Edit Participant"

      assert form_live
             |> form("#participant-form", participant: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#participant-form", participant: @update_attrs)
               |> render_submit()
               |> follow_redirect(
                 conn,
                 ~p"/events/#{event}/batches/#{batch}/participants/#{participant}"
               )

      html = render(show_live)
      assert html =~ "Participant updated successfully"
      assert html =~ "some updated name"
    end
  end
end
