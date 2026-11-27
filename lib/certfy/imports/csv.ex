defmodule Certfy.Imports.CSV do
  @moduledoc """
  Reads CSV bytes with BOM/encoding and delimiter detection.
  """

  alias Certfy.Imports.CSV.{Comma, Semicolon, Tab}

  @delimiters [{?;, Semicolon}, {?,, Comma}, {?\t, Tab}]
  @max_bytes 5_000_000

  def load(binary) when is_binary(binary) do
    cond do
      byte_size(binary) > @max_bytes ->
        {:error, :too_large}

      true ->
        with {:ok, text, metadata} <- decode(binary) do
          delimiter = detect_delimiter(text)
          parser = parser_for(delimiter)

          case parse_with_fallback(parser, text) do
            {:ok, rows} ->
              {:ok, rows, Map.put(metadata, :delimiter, delimiter)}

            {:error, reason} ->
              {:error, reason}
          end
        end
    end
  end

  defp parse_with_fallback(parser, text) do
    try do
      {:ok, parser.parse_string(text, skip_headers: false)}
    rescue
      _ ->
        Enum.find_value(@delimiters, {:error, :parse_error}, fn {_delimiter, fallback} ->
          try do
            {:ok, fallback.parse_string(text, skip_headers: false)}
          rescue
            _ -> nil
          end
        end)
    end
  end

  defp parser_for(delimiter) do
    @delimiters |> Enum.find_value(fn {d, module} -> if d == delimiter, do: module end) ||
      Semicolon
  end

  defp detect_delimiter(text) do
    lines =
      text
      |> String.split(~r/\r\n|\n|\r/)
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.take(20)

    scores =
      Enum.map(@delimiters, fn {delimiter, _module} ->
        counts = Enum.map(lines, &count_outside_quotes(&1, delimiter))
        modal = mode(counts)
        consistent = Enum.count(counts, &(&1 == modal))
        {delimiter, modal, consistent, Enum.sum(counts)}
      end)

    scores
    |> Enum.reject(fn {_d, modal, _consistent, _total} -> modal == 0 end)
    |> case do
      [] ->
        ?;

      candidates ->
        {delimiter, _modal, _consistent, _total} =
          Enum.max_by(candidates, fn {_d, _modal, consistent, total} -> {consistent, total} end)

        delimiter
    end
  end

  defp count_outside_quotes(line, delimiter) do
    {count, _quotes} =
      line
      |> String.to_charlist()
      |> Enum.reduce({0, false}, fn char, {count, quoted?} ->
        cond do
          char == ?" -> {count, not quoted?}
          char == delimiter and not quoted? -> {count + 1, quoted?}
          true -> {count, quoted?}
        end
      end)

    count
  end

  defp mode([]), do: 0

  defp mode(values),
    do: values |> Enum.frequencies() |> Enum.max_by(fn {_value, count} -> count end) |> elem(0)

  defp decode(binary) do
    cond do
      utf16_le?(binary) ->
        decode_utf16(binary, :little, :utf16le)

      utf16_be?(binary) ->
        decode_utf16(binary, :big, :utf16be)

      true ->
        binary = strip_utf8_bom(binary)

        if String.valid?(binary) do
          {:ok, binary, %{encoding: :utf8, warnings: []}}
        else
          text = :unicode.characters_to_binary(binary, :latin1, :utf8)

          {:ok, text, %{encoding: :latin1, warnings: ["Arquivo lido como Windows-1252/Latin-1."]}}
        end
    end
  end

  defp decode_utf16(binary, endian, encoding) do
    <<_bom::binary-size(2), binary::binary>> = binary

    case :unicode.characters_to_binary(binary, {:utf16, endian}, :utf8) do
      text when is_binary(text) ->
        {:ok, text, %{encoding: encoding, warnings: ["Arquivo lido como UTF-16."]}}

      _ ->
        {:error, :invalid_encoding}
    end
  end

  defp strip_utf8_bom(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: rest
  defp strip_utf8_bom(binary), do: binary

  defp utf16_le?(<<0xFF, 0xFE, _::binary>>), do: true
  defp utf16_le?(_), do: false

  defp utf16_be?(<<0xFE, 0xFF, _::binary>>), do: true
  defp utf16_be?(_), do: false
end
