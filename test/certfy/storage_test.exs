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

  test "get_template/1 returns the object body" do
    Process.put(:storage_stub_body, "template content")

    assert Storage.get_template("templates/template.pptx") == {:ok, "template content"}
  end

  test "delete_template/1 deletes the object" do
    Process.put(:storage_stub_notify, self())

    assert Storage.delete_template("templates/template.pptx") == :ok
    assert_receive {:storage_request, :delete, url}
    assert url =~ "template.pptx"
  end
end
