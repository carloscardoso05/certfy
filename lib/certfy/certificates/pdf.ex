defmodule Certfy.Certificates.PDF do
  @moduledoc """
  Converts a PPTX presentation to PDF using Gotenberg's LibreOffice route.
  """

  @timeout 180_000

  def render(pptx) when is_binary(pptx) do
    config = Application.get_env(:certfy, :certificates, [])
    base_url = Keyword.fetch!(config, :pdf_url)
    req_options = Keyword.get(config, :req_options, [])

    fields = [
      files:
        {pptx,
         filename: "template.pptx",
         content_type: "application/vnd.openxmlformats-officedocument.presentationml.presentation"}
    ]

    options =
      Keyword.merge(
        [form_multipart: fields, receive_timeout: @timeout, retry: false],
        req_options
      )

    case Req.post(
           String.trim_trailing(base_url, "/") <> "/forms/libreoffice/convert",
           options
         ) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, truncate(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp truncate(body) when is_binary(body), do: String.slice(body, 0, 500)
  defp truncate(body), do: inspect(body)
end
