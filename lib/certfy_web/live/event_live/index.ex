defmodule CertfyWeb.EventLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Eventos
        <:subtitle>Gerencie os eventos e seus lotes de certificados.</:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/events/new"}>
            <.icon name="hero-plus" /> Novo evento
          </.button>
        </:actions>
      </.header>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body p-0">
          <div class="overflow-x-auto">
            <.table
              id="events"
              rows={@streams.events}
              row_click={fn {_id, event} -> JS.navigate(~p"/events/#{event}") end}
            >
              <:col :let={{_id, event}} label="Nome">
                <span class="font-medium">{event.name}</span>
              </:col>
              <:col :let={{_id, event}} label="Tem template?">
                <span class={template_badge(event)}>
                  {if event.template_path, do: "Sim", else: "Não"}
                </span>
              </:col>
              <:col :let={{_id, event}} label="Dados adicionais">
                <span class="badge badge-ghost badge-sm">{map_size(event.extra_data || %{})}</span>
              </:col>
              <:action :let={{_id, event}}>
                <div class="sr-only">
                  <.link navigate={~p"/events/#{event}"}>Ver</.link>
                </div>
                <.link
                  navigate={~p"/events/#{event}/edit"}
                  class="btn btn-ghost btn-xs"
                >
                  Editar
                </.link>
              </:action>
              <:action :let={{id, event}}>
                <.link
                  phx-click={JS.push("delete", value: %{id: event.id}) |> hide("##{id}")}
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
      Events.subscribe_events(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Eventos")
     |> stream(:events, list_events(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(socket.assigns.current_scope, id)
    {:ok, _} = Events.delete_event(socket.assigns.current_scope, event)

    {:noreply, stream_delete(socket, :events, event)}
  end

  @impl true
  def handle_info({type, %Certfy.Events.Event{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :events, list_events(socket.assigns.current_scope), reset: true)}
  end

  defp list_events(current_scope) do
    Events.list_events(current_scope)
  end

  defp template_badge(%{template_path: nil}), do: "badge badge-ghost badge-sm"
  defp template_badge(_event), do: "badge badge-success badge-sm"
end
