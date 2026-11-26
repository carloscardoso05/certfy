defmodule CertfyWeb.Components.SearchableSelect do
  @moduledoc """
  Select with a searchable list of options.

  The native `<select>` is kept in the DOM (visually hidden) so forms keep
  submitting the chosen value. `SearchableSelect` in `assets/js/app.js` turns
  the trigger into a combobox, filters the options locally and dispatches a
  `change` event on the native select so LiveView forms and filters react as
  usual.
  """

  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true, doc: "list of {label, value} tuples"
  attr :selected, :any, default: nil
  attr :label, :string, default: nil
  attr :label_class, :string, default: "label"
  attr :placeholder, :string, default: "Selecione"
  attr :class, :any, default: nil

  def searchable_select(assigns) do
    selected_value = to_string(assigns.selected || "")

    selected_label =
      Enum.find_value(assigns.options, fn {label, value} ->
        if to_string(value) == selected_value, do: label
      end)

    assigns =
      assigns
      |> assign(:selected_value, selected_value)
      |> assign(:selected_label, selected_label)

    ~H"""
    <div
      id={"#{@id}-wrapper"}
      class={["relative", @class]}
      phx-hook="SearchableSelect"
      data-placeholder={@placeholder}
    >
      <label :if={@label} class={@label_class} for={@id}>{@label}</label>

      <button
        type="button"
        id={@id}
        data-trigger
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded="false"
        aria-controls={"#{@id}-listbox"}
        title={@selected_label || @placeholder}
        class="input input-bordered flex w-full cursor-pointer items-center gap-2 text-left"
      >
        <span
          data-label
          class={["min-w-0 grow truncate", is_nil(@selected_label) && "text-base-content/50"]}
        >
          {@selected_label || @placeholder}
        </span>
        <span class="hero-chevron-down size-4 shrink-0 opacity-60" />
      </button>

      <select
        id={"#{@id}-native"}
        name={@name}
        class="sr-only"
        tabindex="-1"
        aria-hidden="true"
      >
        <option value="" selected={@selected_value == ""}>{@placeholder}</option>

        <option
          :for={{label, value} <- @options}
          value={value}
          selected={to_string(value) == @selected_value}
        >
          {label}
        </option>
      </select>

      <div
        data-popup
        hidden
        class="fixed z-50 overflow-hidden rounded-box border border-base-300 bg-base-100 shadow-xl"
      >
        <div class="border-b border-base-300 p-2">
          <input
            type="search"
            data-search
            class="input input-bordered w-full"
            placeholder="Buscar..."
            aria-label={"Buscar em #{@label || @placeholder}"}
            aria-controls={"#{@id}-listbox"}
            autocomplete="off"
            spellcheck="false"
          />
        </div>

        <ul
          id={"#{@id}-listbox"}
          data-list
          role="listbox"
          class="max-h-64 overflow-y-auto p-1"
        >
          <li
            role="option"
            data-option
            data-value=""
            data-label={@placeholder}
            aria-selected={to_string(@selected_value == "")}
            class="flex min-h-11 cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-base hover:bg-base-200"
          >
            <span data-check aria-hidden="true" class="invisible w-4 shrink-0 text-primary">✓</span>
            <span class="break-words">{@placeholder}</span>
          </li>

          <li
            :for={{label, value} <- @options}
            role="option"
            data-option
            data-value={value}
            data-label={label}
            aria-selected={to_string(to_string(value) == @selected_value)}
            class="flex min-h-11 cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-base hover:bg-base-200"
          >
            <span data-check aria-hidden="true" class="invisible w-4 shrink-0 text-primary">✓</span>
            <span class="break-words">{label}</span>
          </li>
        </ul>

        <p data-empty hidden class="px-4 py-3 text-sm text-base-content/60">
          Nenhuma opção encontrada.
        </p>
      </div>
    </div>
    """
  end
end
