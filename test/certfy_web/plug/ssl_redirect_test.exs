defmodule CertfyWeb.SSLRedirectTest do
  use ExUnit.Case, async: false

  import Plug.Conn, only: [get_resp_header: 2]
  import Plug.Test

  alias CertfyWeb.SSLRedirect

  setup do
    previous = Application.get_env(:certfy, :force_ssl)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:certfy, :force_ssl)
      else
        Application.put_env(:certfy, :force_ssl, previous)
      end
    end)

    :ok
  end

  test "redirects plain HTTP when enabled" do
    Application.put_env(:certfy, :force_ssl, true)

    conn = SSLRedirect.call(conn(:get, "/events"), SSLRedirect.init([]))

    assert conn.status == 301
    assert ["https://localhost/events"] = get_resp_header(conn, "location")
  end

  test "keeps plain HTTP when disabled" do
    Application.put_env(:certfy, :force_ssl, false)

    conn = SSLRedirect.call(conn(:get, "/events"), SSLRedirect.init([]))

    assert conn.status == nil
    assert conn.scheme == :http
  end

  test "does not redirect the health endpoint" do
    Application.put_env(:certfy, :force_ssl, true)

    conn = SSLRedirect.call(conn(:get, "/health"), SSLRedirect.init([]))

    assert conn.status == nil
  end
end
