defmodule CertfyWeb.Components.SearchableSelectTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias CertfyWeb.Components.SearchableSelect

  @long_label "Mostra de Cinema Independente de São Paulo - Edição de Inverno 2026"

  test "renders a combobox trigger backed by a native select" do
    html =
      render_component(&SearchableSelect.searchable_select/1,
        id: "batch_event_id",
        name: "batch[event_id]",
        label: "Evento",
        placeholder: "Selecione um evento",
        options: [{"Seminário 2026", 1}, {@long_label, 2}],
        selected: 2
      )

    assert html =~ ~s(id="batch_event_id-native")
    assert html =~ ~s(name="batch[event_id]")
    assert html =~ ~s(role="combobox")
    assert html =~ ~s(data-search)
    assert html =~ @long_label
    assert html =~ ~s(title="#{@long_label}")
    assert html =~ ~s(aria-selected="true")
  end

  test "shows the placeholder when nothing is selected" do
    html =
      render_component(&SearchableSelect.searchable_select/1,
        id: "participant_batch_id",
        name: "participant[batch_id]",
        placeholder: "Selecione um lote",
        options: [{"Lote único", 1}],
        selected: nil
      )

    assert html =~ "Selecione um lote"
    assert html =~ ~s(title="Selecione um lote")
    assert html =~ "Lote único"
  end

  test "accepts string values coming from query params" do
    html =
      render_component(&SearchableSelect.searchable_select/1,
        id: "batch-filter-event",
        name: "event_id",
        placeholder: "Todos os eventos",
        options: [{"Seminário 2026", 1}],
        selected: "1"
      )

    assert html =~ ~s(title="Seminário 2026")
    assert html =~ ~s(aria-selected="true")
  end
end
