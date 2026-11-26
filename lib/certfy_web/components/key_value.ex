defmodule CertfyWeb.Components.KeyValue do
  @moduledoc """
  A key-value editor for map fields, inspired by Filament's KeyValue field.

  The parent LiveView owns the rows and must handle the `:on_add` and
  `:on_remove` events. Use `rows_from_map/1`, `rows_from_params/1` and
  `to_map/1` to move between the map stored in the database and the form rows.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :label, :string, default: "Dados adicionais"
  attr :rows, :list, default: []
  attr :name_prefix, :string, default: "extra_data"
  attr :on_add, :string, required: true
  attr :on_remove, :string, required: true

  def key_value(assigns) do
    ~H"""
    <section id={@id} class="space-y-2">
      <div class="flex items-start justify-between gap-2">
        <div>
          <h2 class="text-sm font-semibold text-base-content/70">{@label}</h2>
          <p class="text-xs text-base-content/60">
            Pares de chave e valor. Chaves vazias são ignoradas.
          </p>
        </div>

        <button
          type="button"
          id={"#{@id}-add"}
          class="btn btn-ghost btn-xs"
          phx-click={@on_add}
        >
          <span class="hero-plus size-4" /> Adicionar
        </button>
      </div>

      <div
        :if={@rows == []}
        class="rounded-box border border-dashed border-base-300 p-4 text-center text-sm text-base-content/60"
      >
        Nenhum dado adicional.
      </div>

      <div :for={row <- @rows} id={"#{@id}-row-#{row.index}"} class="flex items-start gap-2">
        <input
          type="text"
          name={"#{@name_prefix}[#{row.index}][key]"}
          value={row.key}
          placeholder="Chave"
          class="input input-sm flex-1"
          aria-label="Chave"
        />
        <input
          type="text"
          name={"#{@name_prefix}[#{row.index}][value]"}
          value={row.value}
          placeholder="Valor"
          class="input input-sm flex-[2]"
          aria-label="Valor"
        />
        <button
          type="button"
          id={"#{@id}-remove-#{row.index}"}
          class="btn btn-ghost btn-sm text-error"
          phx-click={@on_remove}
          phx-value-index={row.index}
          aria-label="Remover"
        >
          <span class="hero-trash size-4" />
        </button>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, default: "Dados adicionais"
  attr :data, :map, default: %{}
  attr :class, :any, default: nil

  @doc "Displays the key-value pairs stored in the map."
  def key_value_list(assigns) do
    entries =
      (assigns.data || %{})
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map(fn {key, value} -> %{key: to_string(key), value: stringify(value)} end)

    assigns = assign(assigns, :entries, entries)

    ~H"""
    <section id={@id} class={["card bg-base-100 shadow-sm", @class]}>
      <div class="card-body">
        <div class="flex items-center justify-between gap-3">
          <h2 class="card-title text-base">{@label}</h2>
          <span :if={@entries != []} class="badge badge-ghost badge-sm">
            {length(@entries)} {if length(@entries) == 1, do: "item", else: "itens"}
          </span>
        </div>

        <p
          :if={@entries == []}
          class="rounded-box border border-dashed border-base-300 p-4 text-center text-sm text-base-content/60"
        >
          Nenhum dado adicional.
        </p>

        <dl :if={@entries != []} class="divide-y divide-base-200">
          <div
            :for={entry <- @entries}
            class="grid grid-cols-1 gap-1 py-2 sm:grid-cols-[minmax(0,1fr)_minmax(0,2fr)] sm:gap-4"
          >
            <dt class="text-sm break-words text-base-content/60">{entry.key}</dt>
            <dd class="text-sm font-medium whitespace-pre-wrap break-words">{entry.value}</dd>
          </div>
        </dl>
      </div>
    </section>
    """
  end

  @doc "Builds form rows from the map stored in the database."
  def rows_from_map(nil), do: []

  def rows_from_map(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.with_index()
    |> Enum.map(fn {{key, value}, index} ->
      %{index: index, key: to_string(key), value: stringify(value)}
    end)
  end

  @doc "Builds form rows from the `extra_data` form params."
  def rows_from_params(nil), do: []

  def rows_from_params(params) when is_map(params) do
    params
    |> Enum.map(fn {index, row} -> {parse_index(index), row} end)
    |> Enum.reject(fn {index, _row} -> is_nil(index) end)
    |> Enum.sort_by(fn {index, _row} -> index end)
    |> Enum.with_index()
    |> Enum.map(fn {{_old_index, row}, index} ->
      %{index: index, key: Map.get(row, "key", ""), value: Map.get(row, "value", "")}
    end)
  end

  @doc "Converts form rows to the map stored in the database, ignoring empty keys."
  def to_map(rows) do
    Enum.reduce(rows, %{}, fn row, acc ->
      key = String.trim(row.key)

      if key == "" do
        acc
      else
        Map.put(acc, key, row.value)
      end
    end)
  end

  @doc "Appends an empty row."
  def add_row(rows) do
    rows ++ [%{index: length(rows), key: "", value: ""}]
  end

  @doc "Removes the row with the given index and reindexes the remaining ones."
  def remove_row(rows, index) do
    case parse_index(index) do
      nil ->
        rows

      index ->
        rows
        |> Enum.reject(&(&1.index == index))
        |> Enum.with_index()
        |> Enum.map(fn {row, new_index} -> %{row | index: new_index} end)
    end
  end

  defp parse_index(index) when is_integer(index), do: index

  defp parse_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {index, ""} -> index
      _ -> nil
    end
  end

  defp parse_index(_index), do: nil

  defp stringify(nil), do: ""
  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: to_string(value)
end
