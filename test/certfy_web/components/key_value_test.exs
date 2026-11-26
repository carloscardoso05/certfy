defmodule CertfyWeb.Components.KeyValueTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias CertfyWeb.Components.KeyValue

  test "renders indexed key/value inputs" do
    rows = KeyValue.rows_from_map(%{"sala" => "A"})

    html =
      render_component(&KeyValue.key_value/1,
        id: "extra",
        rows: rows,
        on_add: "add_extra",
        on_remove: "remove_extra"
      )

    assert html =~ ~s(name="extra_data[0][key]")
    assert html =~ ~s(name="extra_data[0][value]")
    assert html =~ ~s(value="sala")
    assert html =~ ~s(value="A")
    assert html =~ "extra-add"
    assert html =~ "extra-remove-0"
  end

  test "key_value_list/1 renders pairs and the empty state" do
    html =
      render_component(&KeyValue.key_value_list/1,
        id: "data",
        data: %{"sala" => "Auditório"}
      )

    assert html =~ "Dados adicionais"
    assert html =~ "sala"
    assert html =~ "Auditório"
    assert html =~ "1 item"

    html = render_component(&KeyValue.key_value_list/1, id: "data", data: %{})
    assert html =~ "Nenhum dado adicional."
  end

  test "rows_from_map/1 sorts keys and stringifies values" do
    assert KeyValue.rows_from_map(%{"b" => 2, "a" => "x"}) == [
             %{index: 0, key: "a", value: "x"},
             %{index: 1, key: "b", value: "2"}
           ]

    assert KeyValue.rows_from_map(nil) == []
  end

  test "rows_from_params/1 keeps the submitted order and reindexes" do
    params = %{
      "1" => %{"key" => "b", "value" => "2"},
      "0" => %{"key" => "a", "value" => "1"}
    }

    assert KeyValue.rows_from_params(params) == [
             %{index: 0, key: "a", value: "1"},
             %{index: 1, key: "b", value: "2"}
           ]

    assert KeyValue.rows_from_params(nil) == []
  end

  test "to_map/1 ignores blank keys" do
    rows = [
      %{index: 0, key: "name", value: "Maria"},
      %{index: 1, key: "  ", value: "ignored"},
      %{index: 2, key: "", value: "ignored"}
    ]

    assert KeyValue.to_map(rows) == %{"name" => "Maria"}
  end

  test "add_row/1 and remove_row/2 manage indexes" do
    rows = KeyValue.add_row([])

    assert rows == [%{index: 0, key: "", value: ""}]

    rows =
      rows
      |> KeyValue.add_row()
      |> KeyValue.add_row()

    assert Enum.map(rows, & &1.index) == [0, 1, 2]

    rows = KeyValue.remove_row(rows, "1")
    assert rows == [%{index: 0, key: "", value: ""}, %{index: 1, key: "", value: ""}]
  end
end
