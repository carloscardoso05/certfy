defmodule Certfy.Certificates.Pptx do
  @moduledoc """
  Reads, analyzes and renders PowerPoint templates in pure Elixir.

  The only parts touched are text runs (`<a:t>` inside `<a:r>`) and a text box
  containing `{{qrcode}}`. Everything else in the slide XML is preserved.
  """

  alias Certfy.Certificates.Tags
  alias Certfy.Certificates.Pptx.Slide

  @content_types "[Content_Types].xml"
  @slide_regex ~r{\Appt/slides/slide(\d+)\.xml\z}

  def analyze(binary) when is_binary(binary) do
    with {:ok, entries} <- unzip(binary),
         {:ok, slides} <- slides(entries) do
      {tags, malformed} =
        Enum.reduce(slides, {%{}, []}, fn {index, _name, xml}, {tags, malformed} ->
          result = Slide.analyze(xml)

          tags =
            Enum.reduce(result.tags, tags, fn raw, acc ->
              key = Tags.normalize_key(raw)

              Map.update(
                acc,
                key,
                %{"tag" => key, "raw" => raw, "count" => 1, "slides" => [index]},
                fn entry ->
                  %{
                    entry
                    | "count" => entry["count"] + 1,
                      "slides" => Enum.uniq([index | entry["slides"]])
                  }
                end
              )
            end)

          malformed =
            malformed ++
              Enum.map(result.malformed, fn raw -> %{"raw" => raw, "slide" => index} end)

          {tags, malformed}
        end)

      {:ok,
       %{
         "slides" => length(slides),
         "tags" => tags |> Map.values() |> Enum.sort_by(& &1["tag"]),
         "malformed" => malformed,
         "checked_at" => DateTime.utc_now() |> DateTime.to_iso8601()
       }}
    end
  end

  def render(binary, values, qr_png) when is_binary(binary) and is_map(values) do
    with {:ok, entries} <- unzip(binary),
         {:ok, slides} <- slides(entries),
         :ok <- ensure_no_malformed(slides) do
      {entries, media_name} = ensure_qr_media(entries, slides, qr_png)

      {entries, warnings} =
        Enum.reduce(slides, {entries, []}, fn {_index, name, xml}, {entries, warnings} ->
          {entries, xml} =
            if media_name && Slide.qr_placeholder?(xml) do
              {entries, r_id} = add_image_relationship(entries, name, media_name)
              {entries, Slide.replace_qr(xml, r_id)}
            else
              {entries, xml}
            end

          {xml, slide_warnings} = Slide.replace_tags(xml, values)
          {Map.put(entries, name, xml), warnings ++ slide_warnings}
        end)

      with {:ok, zip} <- rezip(entries) do
        {:ok, zip, Enum.uniq(warnings)}
      end
    end
  end

  defp ensure_no_malformed(slides) do
    malformed =
      Enum.flat_map(slides, fn {_index, _name, xml} ->
        Slide.analyze(xml).malformed
      end)

    if malformed == [], do: :ok, else: {:error, {:malformed_tags, malformed}}
  end

  defp ensure_qr_media(entries, slides, qr_png) do
    if is_binary(qr_png) and qr_png != "" and
         Enum.any?(slides, fn {_index, _name, xml} -> Slide.qr_placeholder?(xml) end) do
      media_name = "certfy-qr-#{System.unique_integer([:positive])}.png"
      entries = Map.put(entries, "ppt/media/#{media_name}", qr_png)
      {ensure_png_content_type(entries), media_name}
    else
      {entries, nil}
    end
  end

  defp add_image_relationship(entries, slide_name, media_name) do
    [_, number] = Regex.run(~r{ppt/slides/slide(\d+)\.xml}, slide_name)
    rels_path = "ppt/slides/_rels/slide#{number}.xml.rels"

    {xml, r_id} =
      case Map.get(entries, rels_path) do
        nil ->
          xml =
            ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>)

          {xml, "rId1"}

        xml ->
          {xml, next_relationship_id(xml)}
      end

    relationship =
      ~s(<Relationship Id="#{r_id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/#{media_name}"/>)

    xml = String.replace(xml, "</Relationships>", relationship <> "</Relationships>")
    {Map.put(entries, rels_path, xml), r_id}
  end

  defp next_relationship_id(xml) do
    ids =
      Regex.scan(~r/\bId="rId(\d+)"/, xml)
      |> Enum.map(fn [_, id] -> String.to_integer(id) end)

    "rId#{Enum.max(ids, fn -> 0 end) + 1}"
  end

  defp ensure_png_content_type(entries) do
    case Map.get(entries, @content_types) do
      nil ->
        entries

      xml ->
        if String.contains?(xml, ~s(Extension="png")) do
          entries
        else
          xml =
            String.replace(
              xml,
              "</Types>",
              ~s(<Default Extension="png" ContentType="image/png"/></Types>)
            )

          Map.put(entries, @content_types, xml)
        end
    end
  end

  defp unzip(binary) do
    case :zip.unzip(binary, [:memory]) do
      {:ok, files} ->
        entries =
          Map.new(files, fn {name, data} -> {to_string(name), data} end)

        if Map.has_key?(entries, @content_types),
          do: {:ok, entries},
          else: {:error, :invalid_pptx}

      {:error, _reason} ->
        {:error, :invalid_zip}
    end
  end

  defp slides(entries) do
    slides =
      entries
      |> Enum.flat_map(fn {name, xml} ->
        case Regex.run(@slide_regex, name) do
          [_, index] -> [{String.to_integer(index), name, xml}]
          _ -> []
        end
      end)
      |> Enum.sort_by(&elem(&1, 0))

    if slides == [], do: {:error, :no_slides}, else: {:ok, slides}
  end

  defp rezip(entries) do
    files =
      Enum.map(entries, fn {name, data} ->
        {String.to_charlist(name), data}
      end)

    case :zip.create(~c"certificate.pptx", files, [:memory]) do
      {:ok, {_name, binary}} -> {:ok, binary}
      {:error, reason} -> {:error, reason}
    end
  end
end
