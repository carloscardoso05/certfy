defmodule Certfy.Imports.Spreadsheet do
  @moduledoc """
  Loads CSV or XLSX bytes into a normalized table.
  """

  alias Certfy.Imports.{CSV, XLSX}

  @max_bytes 5_000_000

  def load(binary, filename \\ "") when is_binary(binary) do
    cond do
      byte_size(binary) > @max_bytes ->
        {:error, :too_large}

      xlsx?(binary) or String.ends_with?(String.downcase(filename), ".xlsx") ->
        with {:ok, rows, meta} <- XLSX.load(binary) do
          normalize(rows, meta)
        end

      true ->
        with {:ok, rows, meta} <- CSV.load(binary) do
          normalize(rows, Map.put(meta, :kind, :csv))
        end
    end
  end

  defp normalize(rows, meta) do
    rows =
      rows
      |> Enum.map(fn row -> Enum.map(row, &to_string/1) end)
      |> Enum.reject(fn row -> Enum.all?(row, &(String.trim(&1) == "")) end)

    width = rows |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)
    rows = Enum.map(rows, fn row -> row ++ List.duplicate("", width - length(row)) end)

    {:ok, rows, Map.merge(meta, %{row_count: length(rows), column_count: width})}
  end

  defp xlsx?(<<0x50, 0x4B, 0x03, 0x04, _::binary>>), do: true
  defp xlsx?(_), do: false
end
