defmodule Certfy.Imports.XLSX do
  @moduledoc """
  Reads the first non-empty sheet of an XLSX file.
  """

  def load(binary) when is_binary(binary) do
    try do
      do_load(binary)
    rescue
      _ -> {:error, :invalid_xlsx}
    catch
      _, _ -> {:error, :invalid_xlsx}
    end
  end

  defp do_load(binary) do
    with {:ok, package} <- XlsxReader.open(binary, source: :binary),
         {:ok, sheet_name} <- first_sheet(package),
         {:ok, rows} <- XlsxReader.sheet(package, sheet_name) do
      rows = Enum.map(rows, fn row -> Enum.map(row, &cell_to_text/1) end)

      {:ok, rows, %{kind: :xlsx, sheet: sheet_name, warnings: []}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_xlsx}
    end
  end

  defp first_sheet(package) do
    names = XlsxReader.sheet_names(package)

    Enum.find_value(names, {:error, :no_sheets}, fn name ->
      case XlsxReader.sheet(package, name) do
        {:ok, rows} ->
          if Enum.any?(rows, &Enum.any?(&1, fn cell -> cell_to_text(cell) != "" end)) do
            {:ok, name}
          end

        _ ->
          nil
      end
    end)
  end

  def cell_to_text(nil), do: ""
  def cell_to_text(value) when is_binary(value), do: value
  def cell_to_text(value) when is_integer(value), do: Integer.to_string(value)
  def cell_to_text(value) when is_float(value), do: format_float(value)
  def cell_to_text(%Date{} = value), do: Calendar.strftime(value, "%d/%m/%Y")
  def cell_to_text(%NaiveDateTime{} = value), do: Calendar.strftime(value, "%d/%m/%Y %H:%M")
  def cell_to_text(%DateTime{} = value), do: Calendar.strftime(value, "%d/%m/%Y %H:%M")
  def cell_to_text(%Time{} = value), do: Calendar.strftime(value, "%H:%M:%S")
  def cell_to_text(true), do: "Sim"
  def cell_to_text(false), do: "Não"
  def cell_to_text(%Decimal{} = value), do: Decimal.to_string(value)
  def cell_to_text(value), do: to_string(value)

  defp format_float(value) do
    if value == Float.round(value) do
      value |> trunc() |> Integer.to_string()
    else
      Float.to_string(value)
    end
  end
end
