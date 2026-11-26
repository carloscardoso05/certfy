defmodule CertfyWeb.ParticipantLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Participante {@participant.id}
        <:subtitle>Dados do participante no lote {@batch.name}.</:subtitle>

        <:actions>
          <.button navigate={~p"/events/#{@event}/batches/#{@batch}/participants"}>
            <.icon name="hero-arrow-left" />
          </.button>

          <.button
            variant="primary"
            navigate={
              ~p"/events/#{@event}/batches/#{@batch}/participants/#{@participant}/edit?return_to=show"
            }
          >
            <.icon name="hero-pencil-square" /> Editar participante
          </.button>
        </:actions>
      </.header>

      <div class="stats stats-vertical w-full border border-base-300 bg-base-100 shadow-sm lg:stats-horizontal">
        <div class="stat">
          <div class="stat-title">Nome</div>
          <div class="stat-value text-lg">{@participant.name}</div>
        </div>
        <div class="stat">
          <div class="stat-title">E-mail</div>
          <div class="stat-value text-base">{@participant.email}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Dados adicionais</div>
          <div class="stat-value text-lg">{map_size(@participant.extra_data || %{})}</div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_participants(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Participante")
     |> assign(
       :participant,
       Events.get_participant!(socket.assigns.current_scope, socket.assigns.batch, id)
     )}
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
     |> push_navigate(
       to: ~p"/events/#{socket.assigns.event}/batches/#{socket.assigns.batch}/participants"
     )}
  end

  def handle_info({type, %Certfy.Events.Participant{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
