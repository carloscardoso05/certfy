defmodule Certfy.Imports.ParticipantPlan do
  @moduledoc """
  Validates spreadsheet rows and prepares participant attributes for import.
  """

  alias Certfy.Imports.Columns

  @name_max 160
  @email_regex ~r/^[^@,;\s]+@[^@,;\s]+$/

  def build(data, columns, header_row \\ 0) do
    name_column = Columns.name_column(columns)
    email_column = Columns.email_column(columns)
    extra_columns = Enum.filter(columns, &(&1.kind == :extra))
    offset = header_row + 2

    result =
      data
      |> Enum.with_index()
      |> Enum.reduce(
        %{valid: [], errors: [], sample: [], blank: 0, emails_cleared: 0},
        fn {row, index}, acc ->
          row_number = offset + index

          if Enum.all?(row, &(String.trim(&1) == "")) do
            %{acc | blank: acc.blank + 1}
          else
            process_row(row, row_number, name_column, email_column, extra_columns, acc)
          end
        end
      )

    result
    |> Map.put(:total, length(data))
    |> Map.put(:invalid, length(result.errors))
    |> Map.put(:sample, result.sample |> Enum.reverse() |> Enum.take(50))
    |> Map.put(:valid, Enum.reverse(result.valid))
    |> Map.put(:rows_with_issues, length(result.errors) + result.blank)
  end

  defp process_row(row, row_number, name_column, email_column, extra_columns, acc) do
    name =
      row
      |> value_at(name_column)
      |> normalize_text()

    email = row |> value_at(email_column) |> normalize_email()
    {email, cleared?} = email_result(email)
    errors = name_errors(name)

    sample = %{
      row: row_number,
      name: name,
      email: email || "",
      status: if(errors == [], do: "ok", else: "erro"),
      message: Enum.join(errors, "; ")
    }

    acc = %{
      acc
      | sample: [sample | acc.sample],
        emails_cleared: acc.emails_cleared + if(cleared?, do: 1, else: 0)
    }

    if errors == [] do
      extra_data =
        Enum.reduce(extra_columns, %{}, fn column, map ->
          value = row |> value_at(column) |> String.trim()
          if value == "", do: map, else: Map.put(map, String.trim(column.key), value)
        end)

      %{
        acc
        | valid: [
            %{name: name, email: email, extra_data: extra_data, row: row_number} | acc.valid
          ]
      }
    else
      %{
        acc
        | errors: [%{row: row_number, name: name, message: Enum.join(errors, "; ")} | acc.errors]
      }
    end
  end

  defp name_errors(name) do
    cond do
      name == "" -> ["Nome é obrigatório"]
      String.length(name) > @name_max -> ["Nome deve ter no máximo #{@name_max} caracteres"]
      true -> []
    end
  end

  defp normalize_text(nil), do: ""

  defp normalize_text(value) do
    value
    |> to_string()
    |> String.replace("\u00A0", " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp normalize_email(nil), do: ""

  defp normalize_email(value) do
    value |> to_string() |> String.trim()
  end

  defp email_result(""), do: {nil, false}

  defp email_result(email) do
    if String.length(email) <= 160 and Regex.match?(@email_regex, email) do
      {email, false}
    else
      {nil, true}
    end
  end

  defp value_at(_row, nil), do: ""
  defp value_at(row, %{index: index}), do: Enum.at(row, index, "")
end
