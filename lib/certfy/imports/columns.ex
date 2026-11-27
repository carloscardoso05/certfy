defmodule Certfy.Imports.Columns do
  @moduledoc """
  Detects the header row and the role of each spreadsheet column.
  """

  @name_synonyms [
    "nome",
    "nome completo",
    "name",
    "full name",
    "participante",
    "aluno",
    "aluna",
    "estudante",
    "inscrito",
    "inscrita",
    "convidado",
    "convidada",
    "colaborador",
    "colaboradora",
    "cliente",
    "pessoa",
    "nome do participante",
    "nome do aluno",
    "nome do inscrito"
  ]

  @email_synonyms [
    "email",
    "e mail",
    "e-mail",
    "correio eletronico",
    "correio",
    "mail",
    "email institucional",
    "email do participante",
    "email do aluno",
    "endereco de email",
    "endereco eletronico"
  ]

  @negative_tokens [
    "responsavel",
    "mae",
    "pai",
    "acompanhante",
    "telefone",
    "whatsapp",
    "cpf",
    "documento",
    "instituicao",
    "escola",
    "empresa",
    "cargo",
    "cidade"
  ]

  def detect(rows, opts \\ [])

  def detect(rows, opts) when is_list(rows) do
    if rows == [] do
      {:error, :empty}
    else
      header_index = header_index(rows, Keyword.get(opts, :header, :auto))

      {headers, data} =
        case header_index do
          nil -> {header_labels(length(hd(rows))), rows}
          index -> {Enum.at(rows, index), Enum.drop(rows, index + 1)}
        end

      columns = build_columns(headers, header_index != nil, data)
      {columns, warnings} = resolve_roles(columns, data, header_index == nil)

      {:ok,
       %{
         header_row: header_index,
         headerless?: header_index == nil,
         headers: headers,
         data: data,
         columns: columns,
         warnings: warnings
       }}
    end
  end

  def set_kind(columns, index, kind) do
    columns
    |> Enum.map(fn column ->
      cond do
        column.index == index -> %{column | kind: kind}
        kind == :name and column.kind == :name -> %{column | kind: :extra}
        kind == :email and column.kind == :email -> %{column | kind: :extra}
        true -> column
      end
    end)
  end

  def name_column(columns), do: Enum.find(columns, &(&1.kind == :name))
  def email_column(columns), do: Enum.find(columns, &(&1.kind == :email))

  def validation_errors(columns) do
    name = name_column(columns)

    errors =
      if name == nil, do: ["Escolha qual coluna contém os nomes."], else: []

    errors =
      if Enum.count(columns, &(&1.kind == :name)) > 1 do
        errors ++ ["Escolha apenas uma coluna de nome."]
      else
        errors
      end

    errors =
      if Enum.count(columns, &(&1.kind == :email)) > 1 do
        errors ++ ["Escolha apenas uma coluna de e-mail."]
      else
        errors
      end

    extra_keys =
      columns
      |> Enum.filter(&(&1.kind == :extra))
      |> Enum.map(&String.trim(&1.key || ""))

    errors =
      if Enum.any?(extra_keys, &(&1 == "")) do
        errors ++ ["Preencha a chave de todas as colunas de dados adicionais."]
      else
        errors
      end

    errors =
      if length(extra_keys) != length(Enum.uniq(extra_keys)) do
        errors ++ ["Há chaves de dados adicionais repetidas."]
      else
        errors
      end

    errors
  end

  defp build_columns(headers, header?, data) do
    headers
    |> Enum.with_index()
    |> Enum.reject(fn {_header, index} -> blank_column?(data, index) end)
    |> Enum.map(fn {header, index} ->
      label =
        if header? and String.trim(header) != "" do
          String.trim(header)
        else
          "Coluna #{column_letter(index)}"
        end

      %{
        index: index,
        header: header,
        label: label,
        kind: :extra,
        key: label,
        samples: samples(data, index)
      }
    end)
  end

  defp blank_column?(data, index) do
    Enum.all?(data, fn row -> String.trim(Enum.at(row, index, "")) == "" end)
  end

  defp resolve_roles(columns, data, _headerless?) do
    warnings = []
    {columns, warnings} = map_by_header(columns, @name_synonyms, :name, warnings)
    {columns, warnings} = map_by_header(columns, @email_synonyms, :email, warnings)

    # Value heuristics are a fallback when headers do not identify a column.
    columns =
      if name_column(columns) == nil do
        case find_value_column(data, &name_value?/1, columns) do
          nil -> columns
          index -> set_kind(columns, index, :name)
        end
      else
        columns
      end

    columns =
      if email_column(columns) == nil do
        case find_value_column(data, &email_value?/1, columns) do
          nil -> columns
          index -> set_kind(columns, index, :email)
        end
      else
        columns
      end

    {columns, warnings}
  end

  defp map_by_header(columns, synonyms, kind, warnings) do
    candidates =
      columns
      |> Enum.filter(fn column ->
        normalized = normalize(column.label)

        Enum.any?(synonyms, &(normalized == normalize(&1))) or
          (Enum.any?(synonyms, &String.contains?(normalized, normalize(&1))) and
             not Enum.any?(@negative_tokens, &String.contains?(normalized, &1)))
      end)

    case candidates do
      [] ->
        {columns, warnings}

      [column | _] ->
        warnings =
          if length(candidates) > 1,
            do:
              warnings ++
                ["Mais de uma coluna parece ser #{kind_label(kind)}; confirme a seleção."],
            else: warnings

        {set_kind(columns, column.index, kind), warnings}
    end
  end

  defp find_value_column(data, predicate, columns) do
    columns
    |> Enum.reject(&negative_label?(&1.label))
    |> Enum.map(& &1.index)
    |> Enum.filter(fn index ->
      values =
        data
        |> Enum.map(&Enum.at(&1, index, ""))
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.take(20)

      values != [] and Enum.count(values, predicate) / length(values) >= 0.8
    end)
    |> List.first()
  end

  defp name_value?(value) do
    value = String.trim(value)

    value != "" and String.length(value) <= 160 and
      not String.contains?(value, "@") and
      not Regex.match?(~r{\A[\d\s.,/-]+\z}u, value) and
      length(String.split(value, ~r/\s+/u)) in 1..8
  end

  defp email_value?(value) do
    Regex.match?(~r/\A[^@,;\s]+@[^@,;\s]+\z/u, String.trim(value))
  end

  # The first row can be forced as the header row (`header: true`), forced as
  # data (`header: false`) or detected automatically (`header: :auto`).
  defp header_index(_rows, true), do: 0
  defp header_index(_rows, false), do: nil
  defp header_index(rows, _auto), do: detect_header_row(rows)

  defp detect_header_row(rows) do
    rows
    |> Enum.take(10)
    |> Enum.with_index()
    |> Enum.find_value(fn {row, index} ->
      hits = Enum.count(row, &header_cell?/1)

      if hits > 0, do: index
    end)
  end

  # Cells with e-mails or long values are data, not column titles. This avoids
  # treating a headerless row as a header just because an e-mail contains
  # a synonym such as "mail".
  defp header_cell?(cell) do
    text = cell |> to_string() |> String.trim()
    normalized = normalize(text)

    text != "" and
      not String.contains?(text, "@") and
      String.length(text) <= 60 and
      Enum.any?(@name_synonyms ++ @email_synonyms, fn synonym ->
        normalized_synonym = normalize(synonym)

        normalized == normalized_synonym or
          String.contains?(normalized, normalized_synonym)
      end)
  end

  defp header_labels(0), do: []
  defp header_labels(count), do: Enum.map(0..(count - 1), &"Coluna #{column_letter(&1)}")

  defp column_letter(index) when index < 26, do: <<?A + index::utf8>>

  defp column_letter(index) do
    prefix = column_letter(div(index, 26) - 1)
    prefix <> <<?A + rem(index, 26)::utf8>>
  end

  defp samples(data, index) do
    data
    |> Enum.map(&Enum.at(&1, index, ""))
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.take(3)
  end

  defp kind_label(:name), do: "Nome"
  defp kind_label(:email), do: "E-mail"

  defp negative_label?(label) do
    normalized = normalize(label)
    Enum.any?(@negative_tokens, &String.contains?(normalized, &1))
  end

  defp normalize(value) do
    value
    |> to_string()
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{M}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, " ")
    |> String.trim()
  end
end
