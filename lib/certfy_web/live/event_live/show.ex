defmodule CertfyWeb.EventLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Evento {@event.id}
        <:subtitle>Detalhes do evento e acesso aos lotes.</:subtitle>

        <:actions>
          <.button navigate={~p"/events"}>
            <.icon name="hero-arrow-left" />
          </.button>

          <.button navigate={~p"/events/#{@event}/batches"}>
            <.icon name="hero-rectangle-stack" /> Lotes
          </.button>

          <.button variant="primary" navigate={~p"/events/#{@event}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Editar evento
          </.button>
        </:actions>
      </.header>

      <div class="stats stats-vertical w-full border border-base-300 bg-base-100 shadow-sm lg:stats-horizontal">
        <div class="stat">
          <div class="stat-title">Nome</div>
          <div class="stat-value text-lg">{@event.name}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Tem template?</div>
          <div class="stat-value text-lg">
            {if @event.template_path, do: "Sim", else: "Não"}
          </div>
        </div>
        <div class="stat">
          <div class="stat-title">Dados adicionais</div>
          <div class="stat-value text-lg">{map_size(@event.extra_data || %{})}</div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_events(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Evento")
     |> assign(:event, Events.get_event!(socket.assigns.current_scope, id))}
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
end
