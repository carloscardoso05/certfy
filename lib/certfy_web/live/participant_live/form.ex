defmodule CertfyWeb.ParticipantLive.Form do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Participant
  alias CertfyWeb.Components.KeyValue

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:participants}>
      <.breadcrumb items={
        if @live_action == :new do
          [
            %{label: "Participantes", navigate: ~p"/participants"},
            %{label: "Novo participante"}
          ]
        else
          [
            %{label: "Participantes", navigate: ~p"/participants"},
            %{label: @event.name, navigate: ~p"/participants?event_id=#{@event.id}"},
            %{label: @batch.name, navigate: ~p"/participants?batch_id=#{@batch.id}"},
            %{label: @participant.name, navigate: ~p"/participants/#{@participant}"},
            %{label: "Editar participante"}
          ]
        end
      } />
      <.header>
        {@page_title}
        <:subtitle>Defina o lote e os dados do participante.</:subtitle>
      </.header>

      <div class="mx-auto w-full max-w-2xl">
        <.form
          for={@form}
          id="participant-form"
          phx-change="validate"
          phx-submit="save"
          phx-hook="UnsavedChanges"
        >
          <.sheet>
            <.section title="Informações do participante">
              <div class="grid gap-4 sm:grid-cols-2">
                <.searchable_select
                  :if={@live_action == :new}
                  id="participant_batch_id"
                  name="participant[batch_id]"
                  label="Lote"
                  placeholder="Selecione um lote"
                  options={@batch_options}
                  selected={@selected_batch_id}
                  class="w-full sm:col-span-2"
                />

                <div :if={@live_action == :edit} class="sm:col-span-2">
                  <label class="label" for="participant_batch_readonly">Lote</label>
                  <input
                    id="participant_batch_readonly"
                    class="input input-bordered w-full disabled:bg-base-200 disabled:text-base-content/80 disabled:opacity-100"
                    value={"#{@event.name} - #{@batch.name}"}
                    disabled
                  />
                  <p class="mt-1 text-sm text-base-content/60">
                    O lote não pode ser alterado depois da criação.
                  </p>
                </div>
                <.input field={@form[:name]} type="text" label="Nome" required />
                <.input field={@form[:email]} type="email" label="E-mail (opcional)" />
              </div>
            </.section>

            <.section
              title="Dados adicionais"
              description="Pares de chave e valor. Chaves vazias são ignoradas."
            >
              <.key_value
                id="participant-extra-data"
                rows={@extra_data_rows}
                on_add="add_extra_data"
                on_remove="remove_extra_data"
                on_move="move_extra_data"
              />
            </.section>

            <footer class="flex flex-wrap justify-end gap-2 bg-base-200/50 px-5 py-4 sm:px-6">
              <.button
                navigate={return_path(@current_scope, @return_to, @participant)}
                variant="soft"
              >
                Cancelar
              </.button>

              <.button phx-disable-with="Salvando..." variant="primary">
                Salvar participante
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
     |> assign(
       :batch_options,
       socket.assigns.current_scope
       |> Events.list_batches_with_events()
       |> Enum.map(fn batch -> {"#{batch.event.name} — #{batch.name}", batch.id} end)
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    participant = Events.get_participant_with_context!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Editar participante")
    |> assign(:participant, participant)
    |> assign(:batch, participant.batch)
    |> assign(:event, participant.batch.event)
    |> assign(:selected_batch_id, participant.batch_id)
    |> assign(:extra_data_rows, KeyValue.rows_from_map(participant.extra_data))
    |> assign(
      :form,
      to_form(Events.change_participant(socket.assigns.current_scope, participant))
    )
  end

  defp apply_action(socket, :new, params) do
    participant = %Participant{user_id: socket.assigns.current_scope.user.id}
    selected_batch_id = params["batch_id"]

    batch =
      case selected_batch_id do
        nil ->
          nil

        id ->
          try do
            Events.get_batch_with_event!(socket.assigns.current_scope, id)
          rescue
            Ecto.NoResultsError -> nil
          end
      end

    socket
    |> assign(:page_title, "Novo participante")
    |> assign(:participant, participant)
    |> assign(:batch, batch)
    |> assign(:event, batch && batch.event)
    |> assign(:selected_batch_id, if(batch, do: batch.id, else: nil))
    |> assign(:extra_data_rows, [])
    |> assign(
      :form,
      to_form(Events.change_participant(socket.assigns.current_scope, participant))
    )
  end

  @impl true
  def handle_event("validate", %{"participant" => participant_params} = params, socket) do
    {participant_params, rows} = merge_extra_data(params, participant_params)

    socket =
      if socket.assigns.live_action == :new do
        assign(socket, :selected_batch_id, participant_params["batch_id"])
      else
        socket
      end

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

  def handle_event("move_extra_data", %{"index" => index, "direction" => direction}, socket) do
    {:noreply,
     assign(
       socket,
       :extra_data_rows,
       KeyValue.move_row(socket.assigns.extra_data_rows, index, direction)
     )}
  end

  def handle_event("save", %{"participant" => participant_params} = params, socket) do
    {participant_params, rows} = merge_extra_data(params, participant_params)
    socket = assign(socket, :extra_data_rows, rows)

    case resolve_batch(socket, participant_params) do
      {:ok, batch, participant_params} ->
        save_participant(socket, socket.assigns.live_action, batch, participant_params)

      :error ->
        {:noreply, put_flash(socket, :error, "Selecione um lote para o participante.")}
    end
  end

  defp resolve_batch(socket, participant_params) do
    {batch_id, participant_params} = Map.pop(participant_params, "batch_id")

    case socket.assigns.live_action do
      :edit ->
        {:ok, socket.assigns.batch, participant_params}

      :new ->
        case batch_id do
          id when id in [nil, ""] ->
            :error

          id ->
            try do
              {:ok, Events.get_batch_with_event!(socket.assigns.current_scope, id),
               participant_params}
            rescue
              Ecto.NoResultsError -> :error
            end
        end
    end
  end

  defp save_participant(socket, :edit, _batch, participant_params) do
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
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, participant)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_participant(socket, :new, batch, participant_params) do
    case Events.create_participant(
           socket.assigns.current_scope,
           batch,
           participant_params
         ) do
      {:ok, participant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Participante criado com sucesso.")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, participant)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp merge_extra_data(params, form_params) do
    rows = KeyValue.rows_from_params(params["extra_data"])
    {Map.put(form_params, "extra_data", KeyValue.to_map(rows)), rows}
  end

  defp return_path(_scope, "index", _participant), do: ~p"/participants"
  defp return_path(_scope, "show", participant), do: ~p"/participants/#{participant}"
end
