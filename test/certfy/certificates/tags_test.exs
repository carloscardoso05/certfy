defmodule Certfy.Certificates.TagsTest do
  use ExUnit.Case, async: true

  alias Certfy.Certificates.Tags

  defp values do
    %{
      "participant.name" => "Maria",
      "event.name" => "Seminário",
      "event.horas" => "40",
      "certificate.code" => "ABCDE12345"
    }
  end

  test "normalizes accents, case and punctuation" do
    assert Tags.normalize_key("Nome Completo") == "nome_completo"
    assert Tags.normalize_key("E-mail") == "e_mail"
    assert Tags.normalize_key("Endereço") == "endereco"
    assert Tags.normalize_key("event.Horas") == "event.horas"
  end

  test "replaces tags in escaped text" do
    assert {"Olá, Maria. 40h", []} =
             Tags.replace("Olá, {{participant.name}}. {{event.horas}}h", values())
  end

  test "accepts spaces and different casing in tags" do
    assert {"Maria", []} = Tags.replace("{{ Participant.Name }}", values())
  end

  test "removes unknown tags and reports them" do
    assert {"Olá, .", ["participant.telefone"]} =
             Tags.replace("Olá, {{participant.telefone}}.", values())
  end

  test "keeps the qrcode tag for the renderer" do
    assert {"{{qrcode}}", []} = Tags.replace("{{qrcode}}", values())
  end

  test "escapes value HTML" do
    assert {"&lt;b&gt;Maria&lt;/b&gt;", []} =
             Tags.replace("{{participant.name}}", %{"participant.name" => "<b>Maria</b>"})
  end

  test "builds prefixed values from the participant context" do
    participant = %{name: "Maria", email: nil, extra_data: %{"Empresa" => "Certfy"}}
    batch = %{name: "Lote 1", extra_data: %{"Turno" => "Manhã"}}
    event = %{name: "Seminário", extra_data: %{"Horas" => 40}}
    certificate = %{code: "ABCDE12345"}

    map = Tags.build(participant, batch, event, certificate)

    assert map["participant.name"] == "Maria"
    assert map["participant.email"] == ""
    assert map["participant.empresa"] == "Certfy"
    assert map["batch.turno"] == "Manhã"
    assert map["event.horas"] == "40"
    assert map["certificate.code"] == "ABCDE12345"
    assert map["certificate.issued_at"] =~ ~r/\d{2}\/\d{2}\/\d{4}/
  end
end
