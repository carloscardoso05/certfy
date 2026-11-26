defmodule CertfyWeb.ResourceHooks do
  import Phoenix.Component, only: [assign: 3]

  alias Certfy.Events

  def on_mount(:load_event, %{"event_id" => event_id}, _session, socket) do
    event = Events.get_event!(socket.assigns.current_scope, event_id)
    {:cont, socket |> assign(:event, event)}
  end

  def on_mount(:load_batch, %{"batch_id" => batch_id}, _session, socket) do
    batch =
      Events.get_batch!(socket.assigns.current_scope, socket.assigns.event, batch_id)

    {:cont, socket |> assign(:batch, batch)}
  end
end
