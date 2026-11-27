defmodule Certfy.Certificates.PptxTest do
  use ExUnit.Case, async: true

  alias Certfy.Certificates.Pptx

  @template "test/fixtures/certificate_template.pptx"
  @invalid "test/fixtures/certificate_template_invalid.pptx"

  @values %{
    "participant.name" => "Maria da Silva",
    "participant.email" => "maria@exemplo.com",
    "event.name" => "Seminário 2026",
    "event.horas" => "40",
    "batch.name" => "Lote 1",
    "certificate.code" => "ABCDE12345",
    "certificate.issued_at" => "27/11/2026"
  }

  test "analyzes tags and slide count" do
    assert {:ok, report} = Pptx.analyze(File.read!(@template))
    assert report["slides"] == 1
    tags = Enum.map(report["tags"], & &1["tag"])
    assert "participant.name" in tags
    assert "event.horas" in tags
    assert "qrcode" in tags
    assert report["malformed"] == []
  end

  test "detects malformed tags" do
    assert {:ok, report} = Pptx.analyze(File.read!(@invalid))
    assert report["malformed"] != []
  end

  test "replaces tags across runs, tables and groups and inserts the QR" do
    binary = File.read!(@template)
    {:ok, qr} = Certfy.Certificates.QR.png("ABCDE12345")

    assert {:ok, merged, []} = Pptx.render(binary, @values, qr)

    {:ok, entries} = :zip.unzip(merged, [:memory])
    files = Map.new(entries, fn {name, data} -> {to_string(name), data} end)
    xml = files["ppt/slides/slide1.xml"]

    assert xml =~ "Maria da Silva"
    assert xml =~ "Seminário 2026"
    assert xml =~ "Lote: Lote 1"
    assert xml =~ "E-mail: maria@exemplo.com"
    assert xml =~ "Horas: 40"
    refute xml =~ "{{participant"
    refute xml =~ "{{event"
    assert xml =~ "<p:pic>"
    assert xml =~ "r:embed"

    assert Enum.any?(Map.keys(files), &String.starts_with?(&1, "ppt/media/certfy-qr-"))
    assert files["ppt/slides/_rels/slide1.xml.rels"] =~ "relationships/image"
    assert files["[Content_Types].xml"] =~ ~s(Extension="png")
  end

  test "warns about tags without values but still renders" do
    values = Map.delete(@values, "event.horas")
    {:ok, qr} = Certfy.Certificates.QR.png("ABCDE12345")

    assert {:ok, _merged, warnings} = Pptx.render(File.read!(@template), values, qr)
    assert "Tag sem valor: {{event.horas}}" in warnings
  end

  test "refuses to render a template with malformed tags" do
    {:ok, qr} = Certfy.Certificates.QR.png("ABCDE12345")

    assert {:error, {:malformed_tags, _tags}} =
             Pptx.render(File.read!(@invalid), @values, qr)
  end

  test "rejects files that are not a PPTX" do
    assert {:error, :invalid_zip} = Pptx.analyze("not a zip")
  end
end
