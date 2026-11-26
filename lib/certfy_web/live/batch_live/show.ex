defmodule CertfyWeb.BatchLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Lote {@batch.id}
        <:subtitle>Gerencie os participantes deste lote.</:subtitle>

        <:actions>
          <.button navigate={~p"/events/#{@event}/batches"}>
            <.icon name="hero-arrow-left" />
          </.button>

          <.button navigate={~p"/events/#{@event}/batches/#{@batch}/participants"}>
            <.icon name="hero-users" /> Participantes
          </.button>

          <.button
            variant="primary"
            navigate={~p"/events/#{@event}/batches/#{@batch}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Editar lote
          </.button>
        </:actions>
      </.header>

      <div class="stats stats-vertical w-full border border-base-300 bg-base-100 shadow-sm lg:stats-horizontal">
        <div class="stat">
          <div class="stat-title">Nome</div>
          <div class="stat-value text-lg">{@batch.name}</div>
        </div>
      </div>

      <.key_value_list id="batch-extra-data-list" data={@batch.extra_data} class="mt-6" />
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_batches(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Lote")
     |> assign(
       :batch,
       Events.get_batch!(socket.assigns.current_scope, socket.assigns.event, id)
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
     |> push_navigate(to: ~p"/events/#{socket.assigns.event}/batches")}
  end

  def handle_info({type, %Certfy.Events.Batch{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
