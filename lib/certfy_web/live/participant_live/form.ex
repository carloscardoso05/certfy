defmodule CertfyWeb.ParticipantLive.Form do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Participant
  alias CertfyWeb.Components.KeyValue

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Participante do lote {@batch.name}.</:subtitle>
      </.header>

      <div class="mx-auto w-full max-w-xl">
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <.form
              for={@form}
              id="participant-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-6"
            >
              <.input field={@form[:name]} type="text" label="Nome" required />
              <.input field={@form[:email]} type="email" label="E-mail" />

              <.key_value
                id="participant-extra-data"
                label="Dados adicionais"
                rows={@extra_data_rows}
                on_add="add_extra_data"
                on_remove="remove_extra_data"
              />

              <footer class="flex flex-wrap justify-end gap-2">
                <.button navigate={
                  return_path(@current_scope, @event, @batch, @return_to, @participant)
                }>
                  Cancelar
                </.button>
                <.button phx-disable-with="Salvando..." variant="primary">
                  Salvar participante
                </.button>
              </footer>
            </.form>
          </div>
        </div>
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
    participant =
      Events.get_participant!(socket.assigns.current_scope, socket.assigns.batch, id)

    socket
    |> assign(:page_title, "Editar participante")
    |> assign(:participant, participant)
    |> assign(:extra_data_rows, KeyValue.rows_from_map(participant.extra_data))
    |> assign(
      :form,
      to_form(Events.change_participant(socket.assigns.current_scope, participant))
    )
  end

  defp apply_action(socket, :new, _params) do
    participant = %Participant{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "Novo participante")
    |> assign(:participant, participant)
    |> assign(:extra_data_rows, [])
    |> assign(
      :form,
      to_form(Events.change_participant(socket.assigns.current_scope, participant))
    )
  end

  @impl true
  def handle_event("validate", %{"participant" => participant_params} = params, socket) do
    {participant_params, rows} = merge_extra_data(params, participant_params)

    changeset =
      Events.change_participant(
        socket.assigns.current_scope,
        socket.assigns.participant,
        participant_params
      )

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

  def handle_event("save", %{"participant" => participant_params} = params, socket) do
    {participant_params, rows} = merge_extra_data(params, participant_params)
    socket = assign(socket, :extra_data_rows, rows)
    save_participant(socket, socket.assigns.live_action, participant_params)
  end

  defp merge_extra_data(params, form_params) do
    rows = KeyValue.rows_from_params(params["extra_data"])
    {Map.put(form_params, "extra_data", KeyValue.to_map(rows)), rows}
  end

  defp save_participant(socket, :edit, participant_params) do
    case Events.update_participant(
           socket.assigns.current_scope,
           socket.assigns.participant,
           participant_params
         ) do
      {:ok, participant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Participante atualizado com sucesso.")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.event,
               socket.assigns.batch,
               socket.assigns.return_to,
               participant
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_participant(socket, :new, participant_params) do
    case Events.create_participant(
           socket.assigns.current_scope,
           socket.assigns.batch,
           participant_params
         ) do
      {:ok, participant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Participante criado com sucesso.")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.event,
               socket.assigns.batch,
               socket.assigns.return_to,
               participant
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, event, batch, "index", _participant) do
    ~p"/events/#{event}/batches/#{batch}/participants"
  end

  defp return_path(_scope, event, batch, "show", participant) do
    ~p"/events/#{event}/batches/#{batch}/participants/#{participant}"
  end
end
