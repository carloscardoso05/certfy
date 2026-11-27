defmodule CertfyWeb.EventLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.breadcrumb items={[
        %{label: "Eventos", navigate: ~p"/events"},
        %{label: @event.name}
      ]} />
      <.header>
        {@event.name}
        <:subtitle>Evento #{@event.id} · gerencie lotes e participantes.</:subtitle>

        <:actions>
          <.button navigate={~p"/events"} aria-label="Voltar para eventos" variant="ghost">
            <.icon name="hero-arrow-left" />
          </.button>

          <.button variant="primary" navigate={~p"/events/#{@event}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Editar evento
          </.button>
        </:actions>
      </.header>

      <.sheet>
        <.section title="Informações">
          <dl class="grid gap-4 sm:grid-cols-3">
            <div>
              <dt class="text-sm text-base-content/60">Nome</dt>

              <dd class="mt-1 text-base font-medium">{@event.name}</dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Template</dt>

              <dd class="mt-1 text-base font-medium">
                {template_status(@event)}
              </dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Atualizado em</dt>

              <dd class="mt-1 text-base">
                {Calendar.strftime(@event.updated_at, "%d/%m/%Y às %H:%M")}
              </dd>
            </div>
          </dl>
        </.section>

        <.section
          title="Template"
          description="Arquivo .pptx usado para gerar os certificados deste evento."
        >
          <p class="text-base text-base-content/70">
            {if @event.template_path,
              do:
                "Template enviado. Gerencie o arquivo, as tags e as pré-visualizações na página do template.",
              else: "Nenhum template enviado ainda."}
          </p>

          <div class="mt-4 flex flex-wrap gap-2">
            <.button navigate={~p"/events/#{@event}/template"} variant="soft">
              <.icon name="hero-rectangle-group" /> Gerenciar template
            </.button>

            <.button
              :if={@event.template_path}
              href={~p"/events/#{@event}/template/download"}
              variant="soft"
            >
              <.icon name="hero-arrow-down-tray" /> Baixar .pptx
            </.button>
          </div>
        </.section>

        <.section title="Dados adicionais">
          <.key_value_list id="event-extra-data-list" data={@event.extra_data} />
        </.section>

        <.section
          title="Lotes"
          description={"#{batch_count_label(@batch_count)} neste evento."}
        >
          <.button navigate={~p"/batches?event_id=#{@event.id}"} variant="soft">
            <.icon name="hero-rectangle-stack" /> Abrir lotes
          </.button>
        </.section>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_events(socket.assigns.current_scope)
    end

    event = Events.get_event!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Evento")
     |> assign(:event, event)
     |> assign(:batch_count, Events.count_batches(socket.assigns.current_scope, event))}
  end

  @impl true
  def handle_info(
        {:updated, %Certfy.Events.Event{id: id} = event},
        %{assigns: %{event: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :event, event)}
  end

  def handle_info(
        {:deleted, %Certfy.Events.Event{id: id}},
        %{assigns: %{event: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "O evento atual foi excluído.")
     |> push_navigate(to: ~p"/events")}
  end

  def handle_info({type, %Certfy.Events.Event{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  defp batch_count_label(1), do: "1 lote"
  defp batch_count_label(total), do: "#{total} lotes"

  defp template_status(%{template_path: nil}), do: "Nenhum"

  defp template_status(event) do
    malformed = get_in(event.template_report || %{}, ["malformed"]) || []

    if malformed == [], do: "Enviado", else: "Enviado (com tags malformadas)"
  end
end
