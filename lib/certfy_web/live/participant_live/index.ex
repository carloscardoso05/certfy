defmodule CertfyWeb.ParticipantLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Participants
        <:actions>
          <.button
            variant="primary"
            navigate={~p"/events/#{@event}/batches/#{@batch}/participants/new"}
          >
            <.icon name="hero-plus" /> New Participant
          </.button>
        </:actions>
      </.header>

      <.table
        id="participants"
        rows={@streams.participants}
        row_click={
          fn {_id, participant} ->
            JS.navigate(~p"/events/#{@event}/batches/#{@batch}/participants/#{participant}")
          end
        }
      >
        <:col :let={{_id, participant}} label="Name">{participant.name}</:col>
        <:col :let={{_id, participant}} label="Email">{participant.email}</:col>
        <:col :let={{_id, participant}} label="Extra data">{inspect(participant.extra_data)}</:col>
        <:action :let={{_id, participant}}>
          <div class="sr-only">
            <.link navigate={~p"/events/#{@event}/batches/#{@batch}/participants/#{participant}"}>
              Show
            </.link>
          </div>
          <.link navigate={~p"/events/#{@event}/batches/#{@batch}/participants/#{participant}/edit"}>
            Edit
          </.link>
        </:action>
        <:action :let={{id, participant}}>
          <.link
            phx-click={JS.push("delete", value: %{id: participant.id}) |> hide("##{id}")}
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
      Events.subscribe_participants(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Listing Participants")
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
