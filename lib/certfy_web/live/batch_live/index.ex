defmodule CertfyWeb.BatchLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Lotes do evento {@event.name}
        <:subtitle>Organize os participantes em lotes.</:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/events/#{@event}/batches/new"}>
            <.icon name="hero-plus" /> Novo lote
          </.button>
        </:actions>
      </.header>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body p-0">
          <div class="overflow-x-auto">
            <.table
              id="batches"
              rows={@streams.batches}
              row_click={fn {_id, batch} -> JS.navigate(~p"/events/#{@event}/batches/#{batch}") end}
            >
              <:col :let={{_id, batch}} label="Nome">
                <span class="font-medium">{batch.name}</span>
              </:col>
              <:col :let={{_id, batch}} label="Dados adicionais">
                <span class="badge badge-ghost badge-sm">{map_size(batch.extra_data || %{})}</span>
              </:col>
              <:action :let={{_id, batch}}>
                <div class="sr-only">
                  <.link navigate={~p"/events/#{@event}/batches/#{batch}"}>Ver</.link>
                </div>
                <.link
                  navigate={~p"/events/#{@event}/batches/#{batch}/edit"}
                  class="btn btn-ghost btn-xs"
                >
                  Editar
                </.link>
              </:action>
              <:action :let={{id, batch}}>
                <.link
                  phx-click={JS.push("delete", value: %{id: batch.id}) |> hide("##{id}")}
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
      Events.subscribe_batches(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Lotes")
     |> stream(:batches, list_batches(socket.assigns.current_scope, socket.assigns.event))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    batch = Events.get_batch!(socket.assigns.current_scope, socket.assigns.event, id)
    {:ok, _} = Events.delete_batch(socket.assigns.current_scope, batch)

    {:noreply, stream_delete(socket, :batches, batch)}
  end

  @impl true
  def handle_info({type, %Certfy.Events.Batch{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply,
     stream(
       socket,
       :batches,
       list_batches(socket.assigns.current_scope, socket.assigns.event),
       reset: true
     )}
  end

  defp list_batches(current_scope, event) do
    Events.list_batches(current_scope, event)
  end
end
