defmodule Certfy.StorageStub do
  @moduledoc false

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(method, url, _body, _headers, _http_opts) do
    if pid = Process.get(:storage_stub_notify) do
      send(pid, {:storage_request, method, url})
    end

    status_code = Process.get(:storage_stub_status, 200)
    body = if method in [:get, "GET"], do: Process.get(:storage_stub_body, ""), else: ""

    {:ok, %{status_code: status_code, headers: [], body: body}}
  end
end
