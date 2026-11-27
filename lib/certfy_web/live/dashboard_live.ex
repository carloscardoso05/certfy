defmodule CertfyWeb.DashboardLive do
  use CertfyWeb, :live_view

  alias Certfy.{Certificates, Dashboard, Events}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:home}>
      <.header>
        Início
        <:subtitle>Um panorama dos seus eventos e certificados.</:subtitle>

        <:actions>
          <.button variant="soft" navigate={~p"/como-funciona"}>
            <.icon name="hero-question-mark-circle" /> Como funciona
          </.button>

          <.button variant="primary" navigate={~p"/events?novo=1"}>
            <.icon name="hero-plus" /> Novo evento
          </.button>
        </:actions>
      </.header>

      <div
        :if={@summary.events == 0}
        class="rounded-box border border-base-300 bg-base-100 p-6 sm:p-8"
      >
        <div class="mx-auto max-w-2xl">
          <p class="text-sm font-medium text-primary">Primeiros passos</p>
          <h2 class="mt-1 font-display text-2xl font-semibold">Comece pelo seu primeiro evento</h2>
          <p class="mt-2 text-base-content/70">
            O Certfy organiza a emissão em quatro etapas. Você pode voltar a esta página a qualquer momento.
          </p>

          <ol class="mt-6 space-y-4">
            <.step number="1" title="Crie o evento">
              O evento agrupa os lotes e define o modelo usado nos certificados.
            </.step>

            <.step number="2" title="Crie os lotes">
              Um lote é uma turma, dia ou categoria dentro do evento.
            </.step>

            <.step number="3" title="Cadastre ou importe participantes">
              Cada participante pertence a um lote. Você pode importar uma planilha CSV ou XLSX.
            </.step>

            <.step number="4" title="Gere e envie os certificados">
              Envie o modelo .pptx no evento e gere os PDFs por lote.
            </.step>
          </ol>

          <div class="mt-6 flex flex-wrap gap-2">
            <.button variant="primary" navigate={~p"/events?novo=1"}>
              <.icon name="hero-plus" /> Criar primeiro evento
            </.button>

            <.button variant="soft" navigate={~p"/como-funciona"}>
              Ver o passo a passo
            </.button>
          </div>
        </div>
      </div>

      <div :if={@summary.events > 0} class="space-y-6">
        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <.stat_card
            label="Eventos"
            value={@summary.events}
            icon="hero-calendar-days"
            navigate={~p"/events"}
            link_label="Ver eventos"
          />

          <.stat_card
            label="Lotes"
            value={@summary.batches}
            icon="hero-rectangle-stack"
            navigate={~p"/batches"}
            link_label="Ver todos os lotes"
          />

          <.stat_card
            label="Participantes"
            value={@summary.participants}
            icon="hero-users"
            navigate={~p"/participants"}
            link_label="Ver participantes"
          />

          <div class="rounded-box border border-base-300 bg-base-100 p-5">
            <div class="flex items-center justify-between">
              <p class="text-sm text-base-content/60">Certificados</p>
              <.icon name="hero-document-text" class="size-5 text-base-content/40" />
            </div>

            <div class="mt-3 grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
              <p class="flex items-baseline justify-between gap-2">
                <span class="text-base-content/60">Gerados</span>
                <span class="font-semibold tabular-nums">{@summary.certificates.generated}</span>
              </p>
              <p class="flex items-baseline justify-between gap-2">
                <span class="text-base-content/60">Enviados</span>
                <span class="font-semibold tabular-nums">{@summary.certificates.sent}</span>
              </p>
              <p class="flex items-baseline justify-between gap-2">
                <span class="text-base-content/60">Em andamento</span>
                <span class="font-semibold tabular-nums">{@summary.certificates.pending}</span>
              </p>
              <p class="flex items-baseline justify-between gap-2">
                <span class="text-base-content/60">Com erro</span>
                <span class={[
                  "font-semibold tabular-nums",
                  @summary.certificates.failed > 0 && "text-error"
                ]}>
                  {@summary.certificates.failed}
                </span>
              </p>
            </div>

            <.link
              navigate={~p"/participants?certificate=ready"}
              class="mt-3 inline-flex text-sm font-medium text-primary hover:underline"
            >
              Ver certificados
            </.link>
          </div>
        </div>

        <div
          :if={@alerts != []}
          class="rounded-box border border-warning/30 bg-warning/10 p-5 sm:p-6"
        >
          <h2 class="font-display text-lg font-semibold">Precisa de atenção</h2>

          <ul class="mt-3 divide-y divide-warning/20">
            <li
              :for={alert <- @alerts}
              class="flex flex-wrap items-center gap-2 py-2.5 text-sm first:pt-0 last:pb-0"
            >
              <.icon name={alert.icon} class="size-4 shrink-0 text-warning" />
              <span class="min-w-0 flex-1">{alert.label}</span>
              <.link navigate={alert.path} class="font-medium text-primary hover:underline">
                {alert.action}
              </.link>
            </li>
          </ul>
        </div>

        <div class="overflow-hidden rounded-box border border-base-300 bg-base-100">
          <div class="flex flex-wrap items-center justify-between gap-2 border-b border-base-300 p-5">
            <div>
              <h2 class="font-display text-lg font-semibold">Eventos recentes</h2>
              <p class="mt-1 text-sm text-base-content/60">Os últimos eventos que você atualizou.</p>
            </div>

            <.link navigate={~p"/events"} class="btn btn-soft btn-sm">
              Ver todos
            </.link>
          </div>

          <div class="hidden grid-cols-[minmax(0,1fr)_6rem_7rem_7rem_8rem] gap-4 border-b border-base-300 px-5 py-3 text-sm font-medium text-base-content/70 md:grid">
            <span>Nome</span>
            <span>Lotes</span>
            <span>Participantes</span>
            <span>Modelo</span>
            <span class="text-right">Atualizado</span>
          </div>

          <div class="divide-y divide-base-300">
            <div
              :for={event <- @recent_events}
              id={"recent-event-#{event.id}"}
              class="relative grid grid-cols-1 gap-2 px-5 py-4 hover:bg-base-200/60 md:grid-cols-[minmax(0,1fr)_6rem_7rem_7rem_8rem] md:items-center md:gap-4"
            >
              <.link
                navigate={~p"/events/#{event.id}"}
                class="absolute inset-0 z-0 rounded-box focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
                aria-label={"Abrir #{event.name}"}
              ></.link>

              <p class="min-w-0 truncate font-medium">{event.name}</p>

              <p class="text-sm tabular-nums text-base-content/70">
                <span class="md:hidden">Lotes: </span>{event.batch_count}
              </p>

              <p class="text-sm tabular-nums text-base-content/70">
                <span class="md:hidden">Participantes: </span>{event.participant_count}
              </p>

              <div>
                <span class={["badge badge-sm", template_badge_class(event)]}>
                  {template_label(event)}
                </span>
              </div>

              <p class="text-sm text-base-content/60 md:text-right">
                {Calendar.strftime(event.updated_at, "%d/%m/%Y")}
              </p>
            </div>
          </div>
        </div>

        <p class="text-sm text-base-content/60">
          Precisa relembrar o fluxo? <.link navigate={~p"/como-funciona"} class="link link-hover">Veja como funciona</.link>.
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Events.subscribe_events(socket.assigns.current_scope)
      Events.subscribe_batches(socket.assigns.current_scope)
      Events.subscribe_participants(socket.assigns.current_scope)
      Certificates.subscribe_certificates(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Início")
     |> load_dashboard()}
  end

  @impl true
  def handle_info({type, _record}, socket) when type in [:created, :updated, :deleted] do
    {:noreply, load_dashboard(socket)}
  end

  def handle_info({:certificate_updated, _certificate}, socket) do
    {:noreply, load_dashboard(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp load_dashboard(socket) do
    summary = Dashboard.summary(socket.assigns.current_scope)

    socket
    |> assign(:summary, summary)
    |> assign(:alerts, alerts(summary))
    |> assign(:recent_events, Dashboard.recent_events(socket.assigns.current_scope))
  end

  defp alerts(summary) do
    attention = summary.attention
    certificates = summary.certificates

    [
      attention.events_without_template > 0 &&
        %{
          icon: "hero-document-plus",
          label: "#{attention.events_without_template} evento(s) sem modelo de certificado.",
          path: ~p"/events?template=no",
          action: "Enviar modelo"
        },
      attention.batches_without_participants > 0 &&
        %{
          icon: "hero-user-plus",
          label: "#{attention.batches_without_participants} lote(s) ainda sem participantes.",
          path: ~p"/batches",
          action: "Ver lotes"
        },
      certificates.failed > 0 &&
        %{
          icon: "hero-exclamation-triangle",
          label: "#{certificates.failed} certificado(s) com erro de geração.",
          path: ~p"/participants?certificate=error",
          action: "Ver com erro"
        },
      attention.participants_without_email > 0 &&
        %{
          icon: "hero-envelope-open",
          label: "#{attention.participants_without_email} participante(s) sem e-mail.",
          path: ~p"/participants?certificate=no_email",
          action: "Ver sem e-mail"
        }
    ]
    |> Enum.filter(&is_map/1)
  end

  defp template_label(%{template_path: nil}), do: "Pendente"

  defp template_label(%{template_report: report}) when is_map(report) do
    if (report["malformed"] || []) == [], do: "Enviado", else: "Corrigir"
  end

  defp template_label(_event), do: "Enviado"

  defp template_badge_class(%{template_path: nil}), do: "badge-ghost"

  defp template_badge_class(%{template_report: report}) when is_map(report) do
    if (report["malformed"] || []) == [], do: "badge-success", else: "badge-error"
  end

  defp template_badge_class(_event), do: "badge-success"

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :navigate, :any, required: true
  attr :link_label, :string, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-box border border-base-300 bg-base-100 p-5">
      <div class="flex items-center justify-between">
        <p class="text-sm text-base-content/60">{@label}</p>
        <.icon name={@icon} class="size-5 text-base-content/40" />
      </div>

      <p class="mt-2 text-3xl font-semibold tabular-nums">{@value}</p>

      <.link
        navigate={@navigate}
        class="mt-2 inline-flex text-sm font-medium text-primary hover:underline"
      >
        {@link_label}
      </.link>
    </div>
    """
  end

  attr :number, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp step(assigns) do
    ~H"""
    <li class="flex gap-3">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
        {@number}
      </span>
      <div>
        <p class="font-medium">{@title}</p>
        <p class="mt-1 text-sm text-base-content/65">{render_slot(@inner_block)}</p>
      </div>
    </li>
    """
  end
end
