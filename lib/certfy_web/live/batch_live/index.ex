defmodule CertfyWeb.BatchLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Batches
        <:actions>
          <.button variant="primary" navigate={~p"/events/#{@event}/batches/new"}>
            <.icon name="hero-plus" /> New Batch
          </.button>
        </:actions>
      </.header>

      <.table
        id="batches"
        rows={@streams.batches}
        row_click={fn {_id, batch} -> JS.navigate(~p"/events/#{@event}/batches/#{batch}") end}
      >
        <:col :let={{_id, batch}} label="Name">{batch.name}</:col>
        <:col :let={{_id, batch}} label="Extra data">
          {map_size(batch.extra_data || %{})}
        </:col>
        <:action :let={{_id, batch}}>
          <div class="sr-only">
            <.link navigate={~p"/events/#{@event}/batches/#{batch}"}>Show</.link>
          </div>
          <.link navigate={~p"/events/#{@event}/batches/#{batch}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, batch}}>
          <.link
            phx-click={JS.push("delete", value: %{id: batch.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
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
     |> assign(:page_title, "Listing Batches")
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
