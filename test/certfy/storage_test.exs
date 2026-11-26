defmodule Certfy.StorageTest do
  use ExUnit.Case, async: true

  alias Certfy.Storage

  test "template_key/1 keeps a safe extension" do
    assert Storage.template_key("Template.PPTX") =~ ~r{\Atemplates/[A-Za-z0-9_-]+\.pptx\z}
  end

  test "template_key/1 drops an unsafe extension" do
    assert Storage.template_key("template.exe?") =~ ~r{\Atemplates/[A-Za-z0-9_-]+\z}
  end

  test "template_key/1 generates unique keys" do
    refute Storage.template_key("template.pptx") == Storage.template_key("template.pptx")
  end
end
