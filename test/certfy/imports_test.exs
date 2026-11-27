defmodule Certfy.ImportsTest do
  use ExUnit.Case, async: true

  alias Certfy.Imports.{CSV, Columns, ParticipantPlan, Spreadsheet, XLSX}
  import Certfy.ImportsFixtures

  describe "CSV" do
    test "detects semicolon delimiter" do
      {:ok, rows, meta} = CSV.load("Nome;E-mail\nMaria;maria@example.com\n")

      assert rows == [["Nome", "E-mail"], ["Maria", "maria@example.com"]]
      assert meta.delimiter == ?;
    end

    test "detects comma delimiter and quoted values" do
      {:ok, rows, meta} = CSV.load(~s(Nome,E-mail\n"Silva, Maria",maria@example.com\n))

      assert rows == [["Nome", "E-mail"], ["Silva, Maria", "maria@example.com"]]
      assert meta.delimiter == ?,
    end

    test "detects tab delimiter" do
      {:ok, rows, _meta} = CSV.load("Nome\tE-mail\nMaria\tmaria@example.com\n")

      assert rows == [["Nome", "E-mail"], ["Maria", "maria@example.com"]]
    end

    test "strips the UTF-8 BOM" do
      {:ok, rows, _meta} =
        CSV.load(<<0xEF, 0xBB, 0xBF>> <> "Nome;E-mail\nMaria;maria@example.com\n")

      assert rows == [["Nome", "E-mail"], ["Maria", "maria@example.com"]]
    end

    test "decodes Latin-1 input" do
      {:ok, rows, meta} = CSV.load(<<0x4E, 0x6F, 0x6D, 0x65, 0x3B, 0x4A, 0x6F, 0xE3, 0x6F>>)

      assert rows == [["Nome", "João"]]
      assert meta.encoding == :latin1
    end

    test "decodes UTF-16 input with BOM" do
      utf16 =
        :unicode.characters_to_binary(
          "Nome;E-mail\nMaria;maria@example.com\n",
          :utf8,
          {:utf16, :little}
        )

      {:ok, rows, meta} = CSV.load(<<0xFF, 0xFE>> <> utf16)

      assert rows == [["Nome", "E-mail"], ["Maria", "maria@example.com"]]
      assert meta.encoding == :utf16le
    end

    test "rejects files above the limit" do
      assert CSV.load(String.duplicate("a", 5_000_001)) == {:error, :too_large}
    end
  end

  describe "XLSX" do
    test "reads inline strings from the first sheet" do
      binary = xlsx([["Nome", "E-mail"], ["Maria Silva", "maria@example.com"]])
      {:ok, rows, meta} = XLSX.load(binary)

      assert rows == [["Nome", "E-mail"], ["Maria Silva", "maria@example.com"]]
      assert meta.sheet == "Planilha1"
    end
  end

  describe "Spreadsheet" do
    test "loads XLSX by its ZIP signature" do
      binary = xlsx([["Nome"], ["Maria"]])
      {:ok, rows, meta} = Spreadsheet.load(binary, "lista.bin")

      assert rows == [["Nome"], ["Maria"]]
      assert meta.kind == :xlsx
    end

    test "pads rows and drops fully blank rows" do
      binary = csv([["Nome", "E-mail"], ["Maria"], [], ["João", "joao@example.com"]])

      {:ok, rows, meta} = Spreadsheet.load(binary, "lista.csv")

      assert rows == [["Nome", "E-mail"], ["Maria", ""], ["João", "joao@example.com"]]
      assert meta.column_count == 2
    end

    test "keeps every row without a fixed limit" do
      rows = Enum.map(1..5_100, fn index -> ["Pessoa #{index}"] end)
      binary = csv(rows)

      {:ok, loaded, meta} = Spreadsheet.load(binary, "lista.csv")

      assert length(loaded) == 5_100
      assert meta.row_count == 5_100
    end
  end

  describe "Columns" do
    test "detects name and e-mail headers with accents and caps" do
      {:ok, analysis} =
        Columns.detect([
          ["NOME COMPLETO", "E-MAIL", "Instituição"],
          ["Maria Silva", "maria@example.com", "IFCE"],
          ["João Souza", "joao@example.com", "UFC"]
        ])

      assert Columns.name_column(analysis.columns).index == 0
      assert Columns.email_column(analysis.columns).index == 1
      assert Columns.validation_errors(analysis.columns) == []
      assert Enum.at(analysis.columns, 2).kind == :extra
    end

    test "ignores responsible columns and falls back to values" do
      {:ok, analysis} =
        Columns.detect([
          ["Nome do responsável", "Contato", "Cidade"],
          ["Ana", "ana@example.com", "Fortaleza"],
          ["Bia", "bia@example.com", "Recife"]
        ])

      assert Columns.name_column(analysis.columns) == nil
      assert Enum.find(analysis.columns, &(&1.index == 0)).kind == :extra
      assert Columns.validation_errors(analysis.columns) != []
    end

    test "detects columns without a header row" do
      {:ok, analysis} = Columns.detect([["Maria Silva", "maria@example.com"]])

      assert analysis.headerless?
      assert analysis.header_row == nil
      assert Columns.name_column(analysis.columns).index == 0
      assert Columns.email_column(analysis.columns).index == 1
    end

    test "flags duplicate extra keys" do
      {:ok, analysis} =
        Columns.detect([
          ["Nome", "Cidade", "Cidade"],
          ["Maria", "Fortaleza", "Recife"]
        ])

      assert "Há chaves de dados adicionais repetidas." in Columns.validation_errors(
               analysis.columns
             )
    end

    test "flags more than one name or e-mail column" do
      {:ok, analysis} =
        Columns.detect([
          ["Nome", "Outro nome", "E-mail", "Outro e-mail"],
          ["Maria", "Maria Silva", "maria@example.com", "maria2@example.com"]
        ])

      columns =
        Enum.map(analysis.columns, fn column ->
          case column.index do
            0 -> %{column | kind: :name}
            1 -> %{column | kind: :name}
            2 -> %{column | kind: :email}
            3 -> %{column | kind: :email}
            _ -> column
          end
        end)

      errors = Columns.validation_errors(columns)
      assert "Escolha apenas uma coluna de nome." in errors
      assert "Escolha apenas uma coluna de e-mail." in errors
    end

    test "labels headerless columns beyond Z" do
      row = Enum.map(1..28, &"valor#{&1}")
      {:ok, analysis} = Columns.detect([row])

      assert Enum.at(analysis.columns, 26).label == "Coluna AA"
    end

    test "drops fully blank columns" do
      {:ok, analysis} =
        Columns.detect([
          ["Maria Silva", "maria@example.com", "", ""],
          ["João Souza", "joao@example.com", "", ""]
        ])

      assert analysis.headerless?
      assert Enum.map(analysis.columns, & &1.index) == [0, 1]
      assert Columns.name_column(analysis.columns).index == 0
      assert Columns.email_column(analysis.columns).index == 1
      assert Columns.validation_errors(analysis.columns) == []
    end

    test "does not treat a row with e-mails as the header row" do
      {:ok, analysis} =
        Columns.detect([
          ["Maria Silva", "maria@gmail.com"],
          ["João Souza", "joao@gmail.com"]
        ])

      assert analysis.headerless?
      assert analysis.header_row == nil
      assert analysis.data |> hd() |> hd() == "Maria Silva"
      assert Columns.name_column(analysis.columns).index == 0
      assert Columns.email_column(analysis.columns).index == 1
    end

    test "keeps columns with values even when the header is empty" do
      {:ok, analysis} =
        Columns.detect([
          ["", "E-mail"],
          ["Maria Silva", "maria@example.com"]
        ])

      assert Enum.map(analysis.columns, & &1.index) == [0, 1]
      assert Columns.name_column(analysis.columns).index == 0
    end

    test "forces the first row as header or as data" do
      rows = [["Maria Silva", "maria@gmail.com"], ["João Souza", "joao@gmail.com"]]

      {:ok, auto} = Columns.detect(rows)
      assert auto.headerless?

      {:ok, with_header} = Columns.detect(rows, header: true)
      assert with_header.header_row == 0
      assert with_header.data == [["João Souza", "joao@gmail.com"]]

      {:ok, headerless} = Columns.detect(rows, header: false)
      assert headerless.header_row == nil
      assert headerless.data == rows
    end

    test "set_kind keeps only one name and one email" do
      {:ok, analysis} =
        Columns.detect([
          ["Nome", "Outro nome", "E-mail"],
          ["Maria", "Maria Silva", "maria@example.com"]
        ])

      columns =
        analysis.columns
        |> Columns.set_kind(1, :name)
        |> Columns.set_kind(2, :email)

      assert Enum.count(columns, &(&1.kind == :name)) == 1
      assert Enum.find(columns, &(&1.index == 1)).kind == :name
      assert Enum.find(columns, &(&1.index == 0)).kind == :extra
    end
  end

  describe "ParticipantPlan" do
    test "validates names, clears invalid emails and keeps extra data" do
      {:ok, analysis} =
        Columns.detect([
          ["Nome", "E-mail", "Cidade", "Curso"],
          ["Maria Silva", "maria@example.com", "Fortaleza", "Elixir"],
          ["João Souza", "sem-arroba", "Recife", ""],
          ["", "vazio@example.com", "", ""]
        ])

      plan = ParticipantPlan.build(analysis.data, analysis.columns, analysis.header_row)

      assert plan.total == 3
      assert length(plan.valid) == 2
      assert plan.invalid == 1
      assert plan.emails_cleared == 1

      [maria, joao] = plan.valid
      assert maria.name == "Maria Silva"
      assert maria.email == "maria@example.com"
      assert maria.extra_data == %{"Cidade" => "Fortaleza", "Curso" => "Elixir"}
      assert maria.row == 2

      assert joao.email == nil
      assert joao.extra_data == %{"Cidade" => "Recife"}
      assert joao.row == 3

      assert [%{row: 4, message: "Nome é obrigatório"}] = plan.errors
    end

    test "imports a headerless sheet without blank extra columns" do
      {:ok, analysis} =
        Columns.detect([
          ["Abraham Silva", "abraham@gmail.com", "", ""],
          ["Maria Souza", "maria@gmail.com", "", ""]
        ])

      plan = ParticipantPlan.build(analysis.data, analysis.columns, -1)

      assert plan.total == 2
      assert length(plan.valid) == 2

      [abraham, maria] = plan.valid
      assert abraham.name == "Abraham Silva"
      assert abraham.row == 1
      assert abraham.email == "abraham@gmail.com"
      assert abraham.extra_data == %{}
      assert maria.extra_data == %{}
      assert Columns.validation_errors(analysis.columns) == []
    end

    test "rejects names above 160 characters" do
      {:ok, analysis} = Columns.detect([["Nome"], [String.duplicate("a", 161)]])
      plan = ParticipantPlan.build(analysis.data, analysis.columns, analysis.header_row)

      assert plan.valid == []
      assert [%{message: "Nome deve ter no máximo 160 caracteres"}] = plan.errors
    end

    test "counts blank rows separately" do
      {:ok, analysis} = Columns.detect([["Nome"], ["Maria"], [""], []])
      plan = ParticipantPlan.build(analysis.data, analysis.columns, analysis.header_row)

      assert plan.total == 3
      assert plan.blank == 2
      assert length(plan.valid) == 1
    end
  end
end
