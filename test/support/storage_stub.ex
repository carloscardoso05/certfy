defmodule Certfy.StorageStub do
  @moduledoc false

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(_method, _url, _body, _headers, _http_opts) do
    {:ok, %{status_code: 200, headers: [], body: ""}}
  end
end
