defmodule CertfyWeb.EventControllerTest do
  use CertfyWeb.ConnCase

  import Certfy.EventsFixtures

  setup :register_and_log_in_user

  describe "GET /events/:id/template" do
    test "downloads the event template", %{conn: conn, scope: scope} do
      event = event_fixture(scope, %{name: "Meu Evento", template_path: "templates/a.pptx"})
      Process.put(:storage_stub_body, "pptx-content")

      conn = get(conn, ~p"/events/#{event}/template")

      assert response(conn, 200) == "pptx-content"

      assert conn
             |> get_resp_header("content-disposition")
             |> hd()
             |> String.contains?("Meu-Evento.pptx")
    end

    test "redirects with an error when the event has no template", %{
      conn: conn,
      scope: scope
    } do
      event = event_fixture(scope, %{template_path: nil})

      conn = get(conn, ~p"/events/#{event}/template")

      assert redirected_to(conn) == ~p"/events/#{event}"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Este evento não tem template."
    end
  end
end
