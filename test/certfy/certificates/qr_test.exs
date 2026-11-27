defmodule Certfy.Certificates.QRTest do
  use ExUnit.Case, async: true

  alias Certfy.Certificates.QR

  test "generates a 10 character code from the unambiguous alphabet" do
    code = QR.code()

    assert String.length(code) == 10
    assert code =~ ~r/\A[A-HJ-NP-Z2-9]{10}\z/
    refute code == QR.code()
  end

  test "renders a PNG data URI" do
    assert QR.png_data_uri("ABCDE12345") =~ ~r/\Adata:image\/png;base64,/
  end
end
