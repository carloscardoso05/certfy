defmodule Certfy.BrandingTest do
  use ExUnit.Case, async: false

  alias Certfy.Branding

  describe "default identity" do
    test "uses the original Certfy name, theme and mark" do
      assert Branding.name() == "Certfy"
      assert Branding.theme() == "certfy"
      assert Branding.mark() == "certfy"
      assert Branding.favicon() == "/images/favicon.svg"
      assert Branding.favicon_type() == "image/svg+xml"
      assert Branding.from_email() == "no-reply@certfy.local"
    end

    test "exposes a usable sender address" do
      assert Branding.from_email() =~ ~r/^[^@\s]+@[^@\s]+$/
    end
  end

  describe "runtime overrides" do
    setup do
      previous = Application.get_env(:certfy, :branding)

      on_exit(fn ->
        if previous do
          Application.put_env(:certfy, :branding, previous)
        else
          Application.delete_env(:certfy, :branding)
        end
      end)

      :ok
    end

    test "reads the configured identity" do
      Application.put_env(:certfy, :branding,
        name: "Outra Marca",
        theme: "certifique",
        mark: "seal",
        from_email: "contato@example.com"
      )

      assert Branding.name() == "Outra Marca"
      assert Branding.theme() == "certifique"
      assert Branding.mark() == "seal"
      assert Branding.favicon() == "/images/favicon.png"
      assert Branding.favicon_type() == "image/png"
      assert Branding.from_email() == "contato@example.com"
    end

    test "ignores blank values" do
      Application.put_env(:certfy, :branding, name: "", theme: nil)

      assert Branding.name() == "Certfy"
      assert Branding.theme() == "certfy"
    end
  end
end
