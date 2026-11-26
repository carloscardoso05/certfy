defmodule CertfyWeb.ParticipantLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:participants}>
      <.breadcrumb items={[
        %{label: "Participantes", navigate: ~p"/participants"},
        %{label: @event.name, navigate: ~p"/participants?event_id=#{@event.id}"},
        %{label: @batch.name, navigate: ~p"/participants?batch_id=#{@batch.id}"},
        %{label: @participant.name}
      ]} />
      <.header>
        {@participant.name}
        <:subtitle>Participante do lote {@batch.name} · {@event.name}.</:subtitle>

        <:actions>
          <.button
            navigate={~p"/participants?batch_id=#{@batch.id}"}
            aria-label="Voltar para participantes"
            variant="ghost"
          >
            <.icon name="hero-arrow-left" />
          </.button>

          <.button
            variant="primary"
            navigate={~p"/participants/#{@participant}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Editar participante
          </.button>
        </:actions>
      </.header>

      <.sheet>
        <.section title="Informações">
          <dl class="grid gap-4 sm:grid-cols-3">
            <div>
              <dt class="text-sm text-base-content/60">Nome</dt>

              <dd class="mt-1 text-base font-medium">{@participant.name}</dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">E-mail</dt>

              <dd class="mt-1 text-base">{@participant.email || "—"}</dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Atualizado em</dt>

              <dd class="mt-1 text-base">
                {Calendar.strftime(@participant.updated_at, "%d/%m/%Y às %H:%M")}
              </dd>
            </div>
          </dl>
        </.section>

        <.section title="Dados adicionais">
          <.key_value_list id="participant-extra-data-list" data={@participant.extra_data} />
        </.section>

        <.section title="Contexto">
          <dl class="grid gap-4 sm:grid-cols-2">
            <div>
              <dt class="text-sm text-base-content/60">Evento</dt>

              <dd class="mt-1 text-base font-medium">
                <.link navigate={~p"/events/#{@event}"} class="link-hover">
                  {@event.name}
                </.link>
              </dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Lote</dt>

              <dd class="mt-1 text-base font-medium">
                <.link navigate={~p"/batches/#{@batch}"} class="link-hover">
                  {@batch.name}
                </.link>
              </dd>
            </div>
          </dl>
        </.section>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_participants(socket.assigns.current_scope)
    end

    participant = Events.get_participant_with_context!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Participante")
     |> assign(:participant, participant)
     |> assign(:batch, participant.batch)
     |> assign(:event, participant.batch.event)}
  end

  @impl true
  def handle_info(
        {:updated, %Certfy.Events.Participant{id: id} = participant},
        %{assigns: %{participant: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :participant, participant)}
  end

  def handle_info(
        {:deleted, %Certfy.Events.Participant{id: id}},
        %{assigns: %{participant: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "O participante atual foi excluído.")
     |> push_navigate(to: ~p"/participants")}
  end

  def handle_info({type, %Certfy.Events.Participant{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
