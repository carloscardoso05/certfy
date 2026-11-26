defmodule CertfyWeb.ParticipantLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Participant {@participant.id}
        <:subtitle>This is a participant record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/participants"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/participants/#{@participant}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit participant
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@participant.name}</:item>
        <:item title="Email">{@participant.email}</:item>
        <:item title="Extra data">{@participant.extra_data}</:item>
      </.list>
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
     |> assign(:page_title, "Show Participant")
     |> assign(:participant, Events.get_participant!(socket.assigns.current_scope, id))}
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
     |> put_flash(:error, "The current participant was deleted.")
     |> push_navigate(to: ~p"/participants")}
  end

  def handle_info({type, %Certfy.Events.Participant{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
