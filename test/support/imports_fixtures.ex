defmodule Certfy.ImportsFixtures do
  @moduledoc """
  Builds CSV and XLSX payloads for import tests.
  """

  def csv(rows, delimiter \\ ";") do
    rows
    |> Enum.map(fn row -> Enum.join(row, delimiter) end)
    |> Enum.join("\n")
  end

  def xlsx(rows) do
    entries = [
      {"[Content_Types].xml", content_types()},
      {"_rels/.rels", root_rels()},
      {"xl/workbook.xml", workbook()},
      {"xl/_rels/workbook.xml.rels", workbook_rels()},
      {"xl/worksheets/sheet1.xml", worksheet(rows)}
    ]

    {:ok, {_name, binary}} =
      :zip.create(
        ~c"planilha.xlsx",
        Enum.map(entries, fn {name, content} -> {String.to_charlist(name), content} end),
        [:memory]
      )

    binary
  end

  defp content_types do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
    </Types>
    """
  end

  defp root_rels do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """
  end

  defp workbook do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="Planilha1" sheetId="1" r:id="rId1"/>
      </sheets>
    </workbook>
    """
  end

  defp workbook_rels do
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
    </Relationships>
    """
  end

  defp worksheet(rows) do
    body =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, row_index} -> row_xml(row, row_index) end)
      |> Enum.join()

    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <sheetData>#{body}</sheetData>
    </worksheet>
    """
  end

  defp row_xml(row, row_index) do
    cells =
      row
      |> Enum.with_index()
      |> Enum.map(fn {value, column_index} ->
        reference = "#{column_letter(column_index)}#{row_index}"

        ~s(<c r="#{reference}" t="inlineStr"><is><t>#{escape(value)}</t></is></c>)
      end)
      |> Enum.join()

    ~s(<row r="#{row_index}">#{cells}</row>)
  end

  defp column_letter(index), do: <<?A + index::utf8>>

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
