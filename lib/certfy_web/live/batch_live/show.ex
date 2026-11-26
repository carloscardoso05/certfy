defmodule CertfyWeb.BatchLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:batches}>
      <.breadcrumb items={[
        %{label: "Lotes", navigate: ~p"/batches"},
        %{label: @event.name, navigate: ~p"/batches?event_id=#{@event.id}"},
        %{label: @batch.name}
      ]} />
      <.header>
        {@batch.name}
        <:subtitle>Lote #{@batch.id} do evento {@event.name}.</:subtitle>

        <:actions>
          <.button navigate={~p"/batches"} aria-label="Voltar para lotes" variant="ghost">
            <.icon name="hero-arrow-left" />
          </.button>

          <.button navigate={~p"/participants?batch_id=#{@batch.id}"} variant="soft">
            <.icon name="hero-users" /> Participantes
          </.button>

          <.button variant="primary" navigate={~p"/batches/#{@batch}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Editar lote
          </.button>
        </:actions>
      </.header>

      <.sheet>
        <.section title="Informações">
          <dl class="grid gap-4 sm:grid-cols-3">
            <div>
              <dt class="text-sm text-base-content/60">Nome</dt>

              <dd class="mt-1 text-base font-medium">{@batch.name}</dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Evento</dt>

              <dd class="mt-1 text-base font-medium">
                <.link navigate={~p"/events/#{@event}"} class="link-hover">
                  {@event.name}
                </.link>
              </dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Atualizado em</dt>

              <dd class="mt-1 text-base">
                {Calendar.strftime(@batch.updated_at, "%d/%m/%Y às %H:%M")}
              </dd>
            </div>
          </dl>
        </.section>

        <.section title="Dados adicionais">
          <.key_value_list id="batch-extra-data-list" data={@batch.extra_data} />
        </.section>

        <.section
          title="Participantes"
          description={"#{participant_count_label(@participant_count)} neste lote."}
        >
          <.button navigate={~p"/participants?batch_id=#{@batch.id}"} variant="soft">
            <.icon name="hero-users" /> Abrir participantes
          </.button>
        </.section>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_batches(socket.assigns.current_scope)
    end

    batch = Events.get_batch_with_event!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Lote")
     |> assign(:batch, batch)
     |> assign(:event, batch.event)
     |> assign(
       :participant_count,
       Events.count_participants(socket.assigns.current_scope, batch)
     )}
  end

  @impl true
  def handle_info(
        {:updated, %Certfy.Events.Batch{id: id} = batch},
        %{assigns: %{batch: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :batch, batch)}
  end

  def handle_info(
        {:deleted, %Certfy.Events.Batch{id: id}},
        %{assigns: %{batch: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "O lote atual foi excluído.")
     |> push_navigate(to: ~p"/batches")}
  end

  def handle_info({type, %Certfy.Events.Batch{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  defp participant_count_label(1), do: "1 participante"
  defp participant_count_label(total), do: "#{total} participantes"
end
