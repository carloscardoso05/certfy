defmodule Certfy.BrandingTest do
  use ExUnit.Case, async: true

  alias Certfy.Branding

  describe "deployment identity" do
    test "exposes the Certifique name, theme and mark" do
      assert Branding.name() == "Certifique"
      assert Branding.theme() == "certifique"
      assert Branding.mark() == "fadesp"
      assert Branding.favicon() == "/images/favicon.png"
    end

    test "exposes a usable sender address" do
      assert Branding.from_email() =~ ~r/^[^@\s]+@[^@\s]+$/
    end
  end
end
