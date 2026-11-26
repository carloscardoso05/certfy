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
      {:ok, _index_live, html} = live(conn, ~p"/events/#{event}/batches")

      assert html =~ "Listing Batches"
      assert html =~ batch.name
    end

    test "does not list batches from another event", %{
      conn: conn,
      scope: scope,
      event: event
    } do
      other_event = event_fixture(scope)
      other_batch = batch_fixture(scope, other_event)

      {:ok, _index_live, html} = live(conn, ~p"/events/#{event}/batches")

      refute html =~ other_batch.name
    end

    test "saves new batch", %{conn: conn, event: event} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{event}/batches")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Batch")
               |> render_click()
               |> follow_redirect(conn, ~p"/events/#{event}/batches/new")

      assert render(form_live) =~ "New Batch"

      assert form_live
             |> form("#batch-form", batch: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#batch-form", batch: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events/#{event}/batches")

      html = render(index_live)
      assert html =~ "Batch created successfully"
      assert html =~ "some name"
    end

    test "updates batch in listing", %{conn: conn, event: event, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{event}/batches")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#batches-#{batch.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/events/#{event}/batches/#{batch}/edit")

      assert render(form_live) =~ "Edit Batch"

      assert form_live
             |> form("#batch-form", batch: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#batch-form", batch: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events/#{event}/batches")

      html = render(index_live)
      assert html =~ "Batch updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes batch in listing", %{conn: conn, event: event, batch: batch} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{event}/batches")

      assert index_live |> element("#batches-#{batch.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#batches-#{batch.id}")
    end
  end

  describe "Show" do
    setup [:create_batch]

    test "displays batch", %{conn: conn, event: event, batch: batch} do
      {:ok, _show_live, html} = live(conn, ~p"/events/#{event}/batches/#{batch}")

      assert html =~ "Show Batch"
      assert html =~ batch.name
    end

    test "updates batch and returns to show", %{conn: conn, event: event, batch: batch} do
      {:ok, show_live, _html} = live(conn, ~p"/events/#{event}/batches/#{batch}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/events/#{event}/batches/#{batch}/edit?return_to=show"
               )

      assert render(form_live) =~ "Edit Batch"

      assert form_live
             |> form("#batch-form", batch: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#batch-form", batch: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/events/#{event}/batches/#{batch}")

      html = render(show_live)
      assert html =~ "Batch updated successfully"
      assert html =~ "some updated name"
    end
  end
end
