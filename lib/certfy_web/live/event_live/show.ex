defmodule CertfyWeb.EventLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Event {@event.id}
        <:subtitle>This is a event record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/events"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/events/#{@event}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit event
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@event.name}</:item>
        <:item title="Template path">{@event.template_path}</:item>
        <:item title="Extra data">{@event.extra_data}</:item>
      </.list>
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
     |> assign(:page_title, "Show Event")
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
     |> put_flash(:error, "The current event was deleted.")
     |> push_navigate(to: ~p"/events")}
  end

  def handle_info({type, %Certfy.Events.Event{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
