defmodule CertfyWeb.Components.Navigation do
  @moduledoc """
  Contextual navigation components used inside events, batches and participants.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: CertfyWeb.Endpoint,
    router: CertfyWeb.Router,
    statics: CertfyWeb.static_paths()

  import CertfyWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a horizontal tab bar for a contextual section.

  Each item is a map with `:label`, `:href`, `:active` and an optional `:count`.
  """
  attr :items, :list, required: true
  attr :aria_label, :string, default: "Navegação da seção"

  def context_tabs(assigns) do
    ~H"""
    <nav aria-label={@aria_label} class="mb-6 overflow-x-auto border-b border-base-300">
      <ul class="flex min-w-max gap-1">
        <li :for={item <- @items}>
          <.link
            navigate={item.href}
            aria-current={if item[:active], do: "page"}
            class={[
              "inline-flex items-center gap-2 border-b-2 px-3 py-3 text-sm font-medium transition-colors",
              if(item[:active],
                do: "border-primary text-primary",
                else:
                  "border-transparent text-base-content/65 hover:border-base-300 hover:text-base-content"
              )
            ]}
          >
            {item.label}
            <span
              :if={not is_nil(item[:count])}
              class={[
                "badge badge-sm tabular-nums",
                if(item[:active], do: "badge-primary badge-soft", else: "badge-ghost")
              ]}
            >
              {item.count}
            </span>
          </.link>
        </li>
      </ul>
    </nav>
    """
  end

  @doc """
  Renders the tabs for an event context.
  """
  attr :event, :map, required: true
  attr :active, :atom, required: true, values: [:overview, :batches, :participants, :template]
  attr :batch_count, :integer, default: nil
  attr :participant_count, :integer, default: nil

  def event_tabs(assigns) do
    event = assigns.event
    active = assigns.active

    items = [
      %{label: "Visão geral", href: ~p"/events/#{event}", active: active == :overview},
      %{
        label: "Lotes",
        href: ~p"/batches?event_id=#{event.id}",
        active: active == :batches,
        count: assigns.batch_count
      },
      %{
        label: "Participantes",
        href: ~p"/participants?event_id=#{event.id}",
        active: active == :participants,
        count: assigns.participant_count
      },
      %{
        label: "Modelo",
        href: ~p"/events/#{event}/template",
        active: active == :template
      }
    ]

    assigns = assign(assigns, :items, items)

    ~H"""
    <.context_tabs items={@items} aria_label="Navegação do evento" />
    """
  end

  @doc """
  Renders the tabs for a batch context.
  """
  attr :batch, :map, required: true
  attr :active, :atom, required: true, values: [:overview, :participants]
  attr :participant_count, :integer, default: nil

  def batch_tabs(assigns) do
    batch = assigns.batch
    active = assigns.active

    items = [
      %{label: "Visão geral", href: ~p"/batches/#{batch}", active: active == :overview},
      %{
        label: "Participantes",
        href: ~p"/participants?batch_id=#{batch.id}",
        active: active == :participants,
        count: assigns.participant_count
      }
    ]

    assigns = assign(assigns, :items, items)

    ~H"""
    <.context_tabs items={@items} aria_label="Navegação do lote" />
    """
  end

  @doc """
  Renders a textual back link, instead of an icon-only button.
  """
  attr :navigate, :any, required: true
  attr :label, :string, required: true

  def back_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="mb-3 inline-flex items-center gap-1.5 text-sm font-medium text-base-content/70 transition-colors hover:text-base-content"
    >
      <.icon name="hero-arrow-left" class="size-4" /> {@label}
    </.link>
    """
  end
end
