defmodule Certfy.Certificates.Tags do
  @moduledoc """
  Builds the tag map for a certificate and replaces `{{tags}}` in templates.

  Tags and extra-data keys are normalized: accents removed, lowercased and
  non-alphanumeric characters replaced by underscores.
  """

  @tag_regex ~r/\{\{\s*([^{}]+?)\s*\}\}/u

  def build(participant, batch, event, certificate) do
    issued_at = Calendar.strftime(DateTime.utc_now(), "%d/%m/%Y")

    %{
      "participante.nome" => to_text(participant.name),
      "participante.email" => to_text(participant.email),
      "lote.nome" => to_text(batch.name),
      "evento.nome" => to_text(event.name),
      "certificado.codigo" => to_text(certificate.code),
      "certificado.data_emissao" => issued_at
    }
    |> put_extra("participante", participant.extra_data)
    |> put_extra("lote", batch.extra_data)
    |> put_extra("evento", event.extra_data)
  end

  @doc """
  Replaces tags in an already HTML-escaped text.

  Returns the replaced text and the list of unknown tags.
  """
  def replace(text, values) when is_binary(text) do
    {text, unknown} =
      Regex.replace(@tag_regex, text, fn _full, tag ->
        key = normalize_key(tag)

        case Map.fetch(values, key) do
          {:ok, value} ->
            escape(value)

          :error ->
            if key == "qrcode", do: "{{qrcode}}", else: ""
        end
      end)
      |> collect_unknown(text, values)

    {text, unknown}
  end

  @doc """
  Normalizes a tag/key: `"Nome Completo"` -> `"nome_completo"`.
  """
  def normalize_key(nil), do: ""

  def normalize_key(key) do
    key
    |> to_string()
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{M}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9.]+/u, "_")
    |> String.replace(~r/_+/u, "_")
    |> String.trim("_")
  end

  defp put_extra(values, prefix, extra_data) when is_map(extra_data) do
    Enum.reduce(extra_data, values, fn {key, value}, acc ->
      normalized = normalize_key(key)
      full_key = prefix <> "." <> normalized
      value = to_text(value)

      if normalized == "" or value == "" do
        acc
      else
        Map.put_new(acc, full_key, value)
      end
    end)
  end

  defp put_extra(values, _prefix, _extra_data), do: values

  defp to_text(nil), do: ""
  defp to_text(value) when is_binary(value), do: value
  defp to_text(value), do: to_string(value)

  defp escape(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp collect_unknown(replaced, original, values) do
    unknown =
      @tag_regex
      |> Regex.scan(original)
      |> Enum.map(fn [_full, tag] -> normalize_key(tag) end)
      |> Enum.reject(&(&1 in ["qrcode"] or Map.has_key?(values, &1)))
      |> Enum.uniq()

    {replaced, unknown}
  end
end
