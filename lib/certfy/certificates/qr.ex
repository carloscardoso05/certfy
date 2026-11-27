defmodule Certfy.Certificates.QR do
  @moduledoc """
  Certificate codes and QR images.
  """

  @alphabet ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  @length 10

  @doc """
  Generates a random 10-character alphanumeric code.
  """
  def code(length \\ @length) do
    for _ <- 1..length, into: "" do
      <<Enum.random(@alphabet)>>
    end
  end

  @doc """
  Renders the code as a PNG binary.
  """
  def png(code) when is_binary(code) do
    with {:ok, qr} <- QRCode.create(code, :medium),
         {:ok, png} <-
           QRCode.render({:ok, qr}, :png, %QRCode.Render.PngSettings{scale: 8}) do
      {:ok, png}
    end
  end

  @doc """
  Renders the code as a PNG data URI.
  """
  def png_data_uri(code) when is_binary(code) do
    with {:ok, png} <- png(code) do
      "data:image/png;base64," <> Base.encode64(png)
    end
  end
end
