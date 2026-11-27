defmodule CertfyWeb.EventLive.Form do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Event
  alias CertfyWeb.Components.KeyValue

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.breadcrumb items={
        if @live_action == :new do
          [
            %{label: "Eventos", navigate: ~p"/events"},
            %{label: "Novo evento"}
          ]
        else
          [
            %{label: "Eventos", navigate: ~p"/events"},
            %{label: @event.name, navigate: ~p"/events/#{@event}"},
            %{label: "Editar evento"}
          ]
        end
      } />
      <.header>
        {@page_title}
        <:subtitle>Preencha os dados do evento e gerencie o template do certificado.</:subtitle>
      </.header>

      <div class="mx-auto w-full max-w-2xl">
        <.form
          for={@form}
          id="event-form"
          phx-change="validate"
          phx-submit="save"
          phx-hook="UnsavedChanges"
        >
          <.sheet>
            <.section title="Informações do evento">
              <.input field={@form[:name]} type="text" label="Nome" required />
            </.section>

            <.section
              title="Dados adicionais"
              description="Pares de chave e valor. Chaves vazias são ignoradas."
            >
              <.key_value
                id="event-extra-data"
                rows={@extra_data_rows}
                on_add="add_extra_data"
                on_remove="remove_extra_data"
                on_move="move_extra_data"
              />
            </.section>

            <.section
              title="Template do certificado"
              description="O arquivo .pptx e o catálogo de tags são gerenciados na página do template."
            >
              <p class="text-base text-base-content/70">
                <%= if @event.id do %>
                  Envie, substitua ou visualize o template deste evento na página dedicada.
                <% else %>
                  Salve o evento primeiro para enviar o template.
                <% end %>
              </p>

              <.button
                :if={@event.id}
                navigate={~p"/events/#{@event}/template"}
                variant="soft"
                class="mt-4"
              >
                <.icon name="hero-rectangle-group" /> Gerenciar template
              </.button>
            </.section>

            <footer class="flex flex-wrap justify-end gap-2 bg-base-200/50 px-5 py-4 sm:px-6">
              <.button navigate={return_path(@current_scope, @return_to, @event)} variant="soft">
                Cancelar
              </.button>

              <.button phx-disable-with="Salvando..." variant="primary">
                Salvar evento
              </.button>
            </footer>
          </.sheet>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Editar evento")
    |> assign(:event, event)
    |> assign(:extra_data_rows, KeyValue.rows_from_map(event.extra_data))
    |> assign(:form, to_form(Events.change_event(socket.assigns.current_scope, event)))
  end

  defp apply_action(socket, :new, _params) do
    event = %Event{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "Novo evento")
    |> assign(:event, event)
    |> assign(:extra_data_rows, [])
    |> assign(:form, to_form(Events.change_event(socket.assigns.current_scope, event)))
  end

  @impl true
  def handle_event("validate", %{"event" => event_params} = params, socket) do
    {event_params, rows} = merge_extra_data(params, event_params)

    changeset =
      Events.change_event(socket.assigns.current_scope, socket.assigns.event, event_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate), extra_data_rows: rows)}
  end

  def handle_event("add_extra_data", _params, socket) do
    {:noreply, assign(socket, :extra_data_rows, KeyValue.add_row(socket.assigns.extra_data_rows))}
  end

  def handle_event("remove_extra_data", %{"index" => index}, socket) do
    {:noreply,
     assign(
       socket,
       :extra_data_rows,
       KeyValue.remove_row(socket.assigns.extra_data_rows, index)
     )}
  end

  def handle_event("move_extra_data", %{"index" => index, "direction" => direction}, socket) do
    {:noreply,
     assign(
       socket,
       :extra_data_rows,
       KeyValue.move_row(socket.assigns.extra_data_rows, index, direction)
     )}
  end

  def handle_event("save", %{"event" => event_params} = params, socket) do
    {event_params, rows} = merge_extra_data(params, event_params)
    socket = assign(socket, :extra_data_rows, rows)

    case save_event(socket, socket.assigns.live_action, event_params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, save_message(socket.assigns.live_action))
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, event)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp merge_extra_data(params, form_params) do
    rows = KeyValue.rows_from_params(params["extra_data"])
    {Map.put(form_params, "extra_data", KeyValue.to_map(rows)), rows}
  end

  defp save_event(socket, :edit, event_params) do
    Events.update_event(socket.assigns.current_scope, socket.assigns.event, event_params)
  end

  defp save_event(socket, :new, event_params) do
    Events.create_event(socket.assigns.current_scope, event_params)
  end

  defp save_message(:new), do: "Evento criado com sucesso."
  defp save_message(:edit), do: "Evento atualizado com sucesso."

  defp return_path(_scope, "index", _event), do: ~p"/events"
  defp return_path(_scope, "show", event), do: ~p"/events/#{event}"
end
