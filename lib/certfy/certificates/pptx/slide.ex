defmodule Certfy.Certificates.Pptx.Slide do
  @moduledoc """
  Finds and replaces `{{tags}}` inside a slide XML, preserving run formatting.

  Only text in `<a:t>` elements is touched; the rest of the slide XML is kept
  byte-for-byte. Tags must stay inside a single paragraph.
  """

  alias Certfy.Certificates.Tags

  @paragraph ~r/<a:p\b[^>]*>.*?<\/a:p>/s
  @run ~r/<a:r\b[^>]*>.*?<\/a:r>/s
  @text_node ~r/<a:t\b[^>]*>(.*?)<\/a:t>/s
  @tag ~r/\{\{\s*([^{}]+?)\s*\}\}/u
  @shape ~r/<p:sp\b[^>]*>.*?<\/p:sp>/s

  def analyze(xml) do
    xml
    |> paragraphs()
    |> Enum.reduce(%{tags: [], malformed: []}, fn paragraph, acc ->
      text = paragraph_text(paragraph)
      {tags, malformed} = scan(text)

      %{
        tags: tags ++ acc.tags,
        malformed: malformed ++ acc.malformed
      }
    end)
  end

  def replace_tags(xml, values) do
    {xml, warnings} =
      map_blocks(xml, @paragraph, fn paragraph, index ->
        replace_paragraph(paragraph, values, index)
      end)
      |> unwrap()

    {xml, warnings}
  end

  def qr_placeholder?(xml) do
    xml
    |> shape_blocks()
    |> Enum.any?(fn shape -> String.trim(shape_text(shape)) == "{{qrcode}}" end)
  end

  def replace_qr(xml, relationship_id) do
    max_id = max_shape_id(xml)

    xml
    |> map_blocks(@shape, fn shape, index ->
      if String.trim(shape_text(shape)) == "{{qrcode}}" do
        {qr_picture(shape, relationship_id, max_id + index + 1), []}
      else
        {shape, []}
      end
    end)
    |> elem(0)
  end

  def max_shape_id(xml) do
    ~r/<p:cNvPr\b[^>]*id="(\d+)"/
    |> Regex.scan(xml)
    |> Enum.map(fn [_, id] -> String.to_integer(id) end)
    |> Enum.max(fn -> 0 end)
  end

  defp replace_paragraph(paragraph, values, _index) do
    text = paragraph_text(paragraph)
    matches = tag_matches(text)

    if matches == [] do
      {paragraph, []}
    else
      runs = run_blocks(paragraph)

      {new_runs, warnings} =
        replace_in_runs(runs, matches, values)

      {map_blocks(paragraph, @run, fn run, index ->
         {Enum.at(new_runs, index, run), []}
       end)
       |> elem(0), warnings}
    end
  end

  defp replace_in_runs(runs, matches, values) do
    texts = Enum.map(runs, &run_text/1)

    starts =
      texts
      |> Enum.reduce({[], 0}, fn text, {acc, offset} ->
        {[{offset, byte_size(text)} | acc], offset + byte_size(text)}
      end)
      |> elem(0)
      |> Enum.reverse()

    ops =
      Enum.reduce(matches, {[], []}, fn {start, length}, {ops, warnings} ->
        raw = binary_part(Enum.join(texts), start, length)
        key = raw |> String.trim_leading("{{") |> String.trim_trailing("}}") |> String.trim()
        key = Tags.normalize_key(key)
        value = Map.get(values, key, "")
        warning = if Map.has_key?(values, key), do: nil, else: "Tag sem valor: {{#{key}}}"

        run_ops =
          Enum.with_index(starts)
          |> Enum.flat_map(fn {{run_start, run_size}, index} ->
            run_end = run_start + run_size

            if start < run_end and start + length > run_start do
              local_start = max(start, run_start) - run_start
              local_end = min(start + length, run_end) - run_start
              insert? = start >= run_start
              [{index, local_start, local_end, insert?, value}]
            else
              []
            end
          end)

        {run_ops ++ ops, if(warning, do: [warning | warnings], else: warnings)}
      end)

    {ops, warnings} = ops
    ops = Enum.reverse(ops)

    new_runs =
      Enum.with_index(runs)
      |> Enum.map(fn {run, index} ->
        run_ops = Enum.filter(ops, fn {run_index, _, _, _, _} -> run_index == index end)
        new_text = apply_ops(Enum.at(texts, index), run_ops)
        replace_run_text(run, new_text)
      end)

    {new_runs, Enum.uniq(warnings)}
  end

  defp apply_ops(text, ops) do
    ops
    |> Enum.sort_by(fn {_index, local_start, _, _, _} -> local_start end)
    |> Enum.reduce({[], 0}, fn {_index, local_start, local_end, insert?, value}, {acc, cursor} ->
      {acc, cursor} =
        if local_start >= cursor do
          {[binary_part(text, cursor, local_start - cursor) | acc], local_end}
        else
          {acc, max(cursor, local_end)}
        end

      {if(insert?, do: [value | acc], else: acc), cursor}
    end)
    |> then(fn {acc, cursor} ->
      rest =
        if cursor < byte_size(text),
          do: binary_part(text, cursor, byte_size(text) - cursor),
          else: ""

      IO.iodata_to_binary(Enum.reverse([rest | acc]))
    end)
  end

  defp replace_run_text(run, new_text) do
    case Regex.run(@text_node, run, return: :index) do
      nil ->
        run

      [{start, length}, _capture] ->
        full = binary_part(run, start, length)
        attrs = Regex.run(~r/^<a:t([^>]*)>/, full) |> then(fn [_, attrs] -> attrs end)
        replacement = "<a:t#{attrs}>#{escape(new_text)}</a:t>"
        String.replace(run, full, replacement, global: false)
    end
  end

  defp run_text(run) do
    case Regex.run(@text_node, run) do
      [_, text] -> unescape(text)
      nil -> ""
    end
  end

  defp paragraph_text(paragraph) do
    @text_node
    |> Regex.scan(paragraph)
    |> Enum.map(fn [_, text] -> unescape(text) end)
    |> Enum.join("")
  end

  defp shape_text(shape), do: paragraph_text(shape)

  defp scan(text) do
    tags = Regex.scan(@tag, text) |> Enum.map(fn [_, tag] -> tag end)
    leftover = Regex.replace(@tag, text, "")

    malformed =
      if String.contains?(leftover, ["{{", "}}"]) do
        [String.slice(String.trim(text), 0, 80)]
      else
        []
      end

    {tags, malformed}
  end

  defp tag_matches(text) do
    @tag
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [match | _] -> match end)
  end

  defp qr_picture(shape, relationship_id, id) do
    {x, y, cx, cy, rotation} = shape_box(shape)

    """
    <p:pic>
      <p:nvPicPr>
        <p:cNvPr id="#{id}" name="QR Code"/>
        <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>
        <p:nvPr/>
      </p:nvPicPr>
      <p:blipFill>
        <a:blip r:embed="#{relationship_id}"/>
        <a:stretch><a:fillRect/></a:stretch>
      </p:blipFill>
      <p:spPr>
        <a:xfrm#{if rotation, do: ~s( rot="#{rotation}"), else: ""}>
          <a:off x="#{x}" y="#{y}"/>
          <a:ext cx="#{cx}" cy="#{cy}"/>
        </a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
      </p:spPr>
    </p:pic>
    """
  end

  defp shape_box(shape) do
    xfrm =
      case Regex.run(~r/<a:xfrm\b([^>]*)>(.*?)<\/a:xfrm>/s, shape) do
        [_, attrs, content] -> {attrs, content}
        _ -> {"", ""}
      end

    {attrs, content} = xfrm
    rotation = attr_value(attrs, "rot")
    x = attr(content, "a:off", "x") || "0"
    y = attr(content, "a:off", "y") || "0"
    cx = attr(content, "a:ext", "cx") || "914400"
    cy = attr(content, "a:ext", "cy") || "914400"

    {x, y, cx, cy, rotation}
  end

  defp attr(xml, element, name) do
    case Regex.run(~r/<#{element}\b([^>]*)\/>/, xml) do
      [_, attrs] -> attr_value(attrs, name)
      _ -> nil
    end
  end

  defp attr_value(attrs, name) do
    case Regex.run(~r/#{name}="([^"]*)"/, attrs) do
      [_, value] -> value
      _ -> nil
    end
  end

  defp map_blocks(text, regex, fun) do
    {text, warnings} = do_map_blocks(text, regex, fun, 0, [])
    {text, warnings}
  end

  defp do_map_blocks(text, regex, fun, index, acc) do
    case Regex.run(regex, text, return: :index) do
      nil ->
        {text, acc}

      [{start, length} | _] ->
        prefix = binary_part(text, 0, start)
        block = binary_part(text, start, length)
        rest_start = start + length
        rest = binary_part(text, rest_start, byte_size(text) - rest_start)
        {replacement, warnings} = fun.(block, index)

        {tail, warnings} = do_map_blocks(rest, regex, fun, index + 1, acc ++ warnings)
        {prefix <> replacement <> tail, warnings}
    end
  end

  defp unwrap({xml, warnings}), do: {xml, warnings}

  defp paragraphs(xml) do
    Regex.scan(@paragraph, xml) |> Enum.map(&hd/1)
  end

  defp run_blocks(paragraph) do
    Regex.scan(@run, paragraph) |> Enum.map(&hd/1)
  end

  defp shape_blocks(xml) do
    Regex.scan(@shape, xml) |> Enum.map(&hd/1)
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp unescape(text) do
    text
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&amp;", "&")
    |> unescape_numeric()
  end

  defp unescape_numeric(text) do
    Regex.replace(~r/&#x([0-9a-fA-F]+);/, text, fn _, hex ->
      <<String.to_integer(hex, 16)::utf8>>
    end)
    |> then(fn text ->
      Regex.replace(~r/&#(\d+);/, text, fn _, dec ->
        <<String.to_integer(dec)::utf8>>
      end)
    end)
  end
end
