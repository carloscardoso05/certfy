defmodule CertfyWeb.ParticipantLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Participantes do lote {@batch.name}
        <:subtitle>Pessoas que receberão os certificados deste lote.</:subtitle>
        <:actions>
          <.button
            variant="primary"
            navigate={~p"/events/#{@event}/batches/#{@batch}/participants/new"}
          >
            <.icon name="hero-plus" /> Novo participante
          </.button>
        </:actions>
      </.header>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body p-0">
          <div class="overflow-x-auto">
            <.table
              id="participants"
              rows={@streams.participants}
              row_click={
                fn {_id, participant} ->
                  JS.navigate(~p"/events/#{@event}/batches/#{@batch}/participants/#{participant}")
                end
              }
            >
              <:col :let={{_id, participant}} label="Nome">
                <span class="font-medium">{participant.name}</span>
              </:col>
              <:col :let={{_id, participant}} label="E-mail">{participant.email}</:col>
              <:col :let={{_id, participant}} label="Dados adicionais">
                <span class="badge badge-ghost badge-sm">
                  {map_size(participant.extra_data || %{})}
                </span>
              </:col>
              <:action :let={{_id, participant}}>
                <div class="sr-only">
                  <.link navigate={
                    ~p"/events/#{@event}/batches/#{@batch}/participants/#{participant}"
                  }>
                    Ver
                  </.link>
                </div>
                <.link
                  navigate={~p"/events/#{@event}/batches/#{@batch}/participants/#{participant}/edit"}
                  class="btn btn-ghost btn-xs"
                >
                  Editar
                </.link>
              </:action>
              <:action :let={{id, participant}}>
                <.link
                  phx-click={JS.push("delete", value: %{id: participant.id}) |> hide("##{id}")}
                  data-confirm="Tem certeza?"
                  class="btn btn-ghost btn-xs text-error"
                >
                  Excluir
                </.link>
              </:action>
            </.table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Events.subscribe_participants(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Participantes")
     |> stream(
       :participants,
       list_participants(socket.assigns.current_scope, socket.assigns.batch)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    participant =
      Events.get_participant!(socket.assigns.current_scope, socket.assigns.batch, id)

    {:ok, _} = Events.delete_participant(socket.assigns.current_scope, participant)

    {:noreply, stream_delete(socket, :participants, participant)}
  end

  @impl true
  def handle_info({type, %Certfy.Events.Participant{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :participants,
       list_participants(socket.assigns.current_scope, socket.assigns.batch),
       reset: true
     )}
  end

  defp list_participants(current_scope, batch) do
    Events.list_participants(current_scope, batch)
  end
end
