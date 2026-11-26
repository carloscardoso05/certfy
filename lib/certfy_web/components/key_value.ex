defmodule CertfyWeb.Components.KeyValue do
  @moduledoc """
  A key-value editor for map fields, inspired by Filament's KeyValue field.

  The parent LiveView owns the rows and must handle the `:on_add` and
  `:on_remove` events. Use `rows_from_map/1`, `rows_from_params/1` and
  `to_map/1` to move between the map stored in the database and the form rows.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :rows, :list, default: []
  attr :name_prefix, :string, default: "extra_data"
  attr :on_add, :string, required: true
  attr :on_remove, :string, required: true
  attr :on_move, :string, required: true

  def key_value(assigns) do
    duplicate_keys =
      assigns.rows
      |> Enum.map(&String.trim(&1.key))
      |> Enum.reject(&(&1 == ""))
      |> Enum.frequencies()
      |> Enum.filter(fn {_key, count} -> count > 1 end)
      |> Enum.map(fn {key, _count} -> key end)
      |> Enum.sort()

    assigns = assign(assigns, :duplicate_keys, duplicate_keys)

    ~H"""
    <section id={@id} class="space-y-2">
      <div class="flex justify-end">
        <button
          type="button"
          id={"#{@id}-add"}
          class="btn btn-soft btn-sm"
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

      <p :if={@duplicate_keys != []} class="text-sm text-warning">
        Chaves duplicadas: {Enum.join(@duplicate_keys, ", ")}. O último valor será mantido.
      </p>

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

        <div class="join join-vertical">
          <button
            type="button"
            class="btn btn-ghost btn-xs join-item"
            phx-click={@on_move}
            phx-value-index={row.index}
            phx-value-direction="up"
            disabled={row.index == 0}
            aria-label="Mover para cima"
          >
            <span class="hero-chevron-up size-3" />
          </button>

          <button
            type="button"
            class="btn btn-ghost btn-xs join-item"
            phx-click={@on_move}
            phx-value-index={row.index}
            phx-value-direction="down"
            disabled={row.index == length(@rows) - 1}
            aria-label="Mover para baixo"
          >
            <span class="hero-chevron-down size-3" />
          </button>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
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
    <div id={@id} class={@class}>
      <p
        :if={@entries == []}
        class="rounded-box border border-dashed border-base-300 p-4 text-center text-base text-base-content/70"
      >
        Nenhum dado adicional.
      </p>

      <div :if={@entries != []}>
        <p class="mb-2 text-sm text-base-content/60">
          {length(@entries)} {if length(@entries) == 1, do: "item", else: "itens"}
        </p>

        <dl class="divide-y divide-base-200">
          <div
            :for={entry <- @entries}
            class="grid grid-cols-1 gap-1 py-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,2fr)] sm:gap-4"
          >
            <dt class="text-sm break-words text-base-content/70">{entry.key}</dt>

            <dd class="text-base font-medium whitespace-pre-wrap break-words">{entry.value}</dd>
          </div>
        </dl>
      </div>
    </div>
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

  @doc "Moves a row up or down and reindexes the list."
  def move_row(rows, index, direction) do
    with index when is_integer(index) <- parse_index(index),
         true <- index >= 0 and index < length(rows) do
      target = if direction == "up", do: index - 1, else: index + 1

      if target < 0 or target >= length(rows) do
        rows
      else
        row = Enum.at(rows, index)
        other = Enum.at(rows, target)

        rows
        |> List.replace_at(index, other)
        |> List.replace_at(target, row)
        |> Enum.with_index()
        |> Enum.map(fn {row, new_index} -> %{row | index: new_index} end)
      end
    else
      _ -> rows
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
