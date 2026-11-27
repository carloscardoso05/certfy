defmodule CertfyWeb.BatchLive.Form do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Batch
  alias CertfyWeb.Components.KeyValue

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.breadcrumb items={
        cond do
          @live_action == :new and @event ->
            [
              %{label: "Eventos", navigate: ~p"/events"},
              %{label: @event.name, navigate: ~p"/events/#{@event}"},
              %{label: "Lotes", navigate: ~p"/batches?event_id=#{@event.id}"},
              %{label: "Novo lote"}
            ]

          @live_action == :new ->
            [
              %{label: "Lotes", navigate: ~p"/batches"},
              %{label: "Novo lote"}
            ]

          true ->
            [
              %{label: "Eventos", navigate: ~p"/events"},
              %{label: @event.name, navigate: ~p"/events/#{@event}"},
              %{label: @batch.name, navigate: ~p"/batches/#{@batch}"},
              %{label: "Editar lote"}
            ]
        end
      } />
      <.header>
        {@page_title}
        <:subtitle>Defina o evento e os dados do lote.</:subtitle>
      </.header>

      <div class="mx-auto w-full max-w-2xl">
        <.form
          for={@form}
          id="batch-form"
          phx-change="validate"
          phx-submit="save"
          phx-hook="UnsavedChanges"
        >
          <.sheet>
            <.section title="Informações do lote">
              <div class="grid gap-4 sm:grid-cols-2">
                <.searchable_select
                  :if={@live_action == :new}
                  id="batch_event_id"
                  name="batch[event_id]"
                  label="Evento"
                  placeholder="Selecione um evento"
                  options={@event_options}
                  selected={@selected_event_id}
                  class="w-full"
                />
                <div :if={@live_action == :edit}>
                  <label class="label" for="batch_event_readonly">Evento</label>
                  <input
                    id="batch_event_readonly"
                    class="input input-bordered w-full disabled:bg-base-200 disabled:text-base-content/80 disabled:opacity-100"
                    value={@event.name}
                    disabled
                  />
                  <p class="mt-1 text-sm text-base-content/60">
                    O evento não pode ser alterado depois da criação.
                  </p>
                </div>
                <.input field={@form[:name]} type="text" label="Nome" required />
              </div>
            </.section>

            <.section
              title="Dados adicionais"
              description="Pares de chave e valor. Chaves vazias são ignoradas."
            >
              <.key_value
                id="batch-extra-data"
                rows={@extra_data_rows}
                on_add="add_extra_data"
                on_remove="remove_extra_data"
                on_move="move_extra_data"
              />
            </.section>

            <footer class="flex flex-wrap justify-end gap-2 bg-base-200/50 px-5 py-4 sm:px-6">
              <.button
                navigate={cancel_path(@live_action, @event, @batch, @return_to)}
                variant="soft"
              >
                Cancelar
              </.button>
              <.button phx-disable-with="Salvando..." variant="primary">Salvar lote</.button>
            </footer>
          </.sheet>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    default = if socket.assigns.live_action == :new, do: "show", else: "index"

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"] || default))
     |> assign(
       :event_options,
       Enum.map(Events.list_events(socket.assigns.current_scope), &{&1.name, &1.id})
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    batch = Events.get_batch_with_event!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Editar lote")
    |> assign(:batch, batch)
    |> assign(:event, batch.event)
    |> assign(:selected_event_id, batch.event_id)
    |> assign(:extra_data_rows, KeyValue.rows_from_map(batch.extra_data))
    |> assign(:form, to_form(Events.change_batch(socket.assigns.current_scope, batch)))
  end

  defp apply_action(socket, :new, params) do
    batch = %Batch{user_id: socket.assigns.current_scope.user.id}
    selected_event_id = params["event_id"]

    event =
      case selected_event_id do
        nil ->
          nil

        id ->
          try do
            Events.get_event!(socket.assigns.current_scope, id)
          rescue
            Ecto.NoResultsError -> nil
          end
      end

    socket
    |> assign(:page_title, "Novo lote")
    |> assign(:batch, batch)
    |> assign(:event, event)
    |> assign(:selected_event_id, if(event, do: event.id, else: nil))
    |> assign(:extra_data_rows, [])
    |> assign(:form, to_form(Events.change_batch(socket.assigns.current_scope, batch)))
  end

  @impl true
  def handle_event("validate", %{"batch" => batch_params} = params, socket) do
    {batch_params, rows} = merge_extra_data(params, batch_params)

    socket =
      if socket.assigns.live_action == :new do
        assign(socket, :selected_event_id, batch_params["event_id"])
      else
        socket
      end

    changeset =
      Events.change_batch(socket.assigns.current_scope, socket.assigns.batch, batch_params)

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

  def handle_event("save", %{"batch" => batch_params} = params, socket) do
    {batch_params, rows} = merge_extra_data(params, batch_params)
    socket = assign(socket, :extra_data_rows, rows)

    case resolve_event(socket, batch_params) do
      {:ok, event, batch_params} ->
        save_batch(socket, socket.assigns.live_action, event, batch_params)

      :error ->
        {:noreply, put_flash(socket, :error, "Selecione um evento para o lote.")}
    end
  end

  defp resolve_event(socket, batch_params) do
    {event_id, batch_params} = Map.pop(batch_params, "event_id")

    case socket.assigns.live_action do
      :edit ->
        {:ok, socket.assigns.event, batch_params}

      :new ->
        case event_id do
          id when id in [nil, ""] ->
            :error

          id ->
            try do
              {:ok, Events.get_event!(socket.assigns.current_scope, id), batch_params}
            rescue
              Ecto.NoResultsError -> :error
            end
        end
    end
  end

  defp save_batch(socket, :edit, _event, batch_params) do
    case Events.update_batch(socket.assigns.current_scope, socket.assigns.batch, batch_params) do
      {:ok, batch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lote atualizado com sucesso.")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, batch)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_batch(socket, :new, event, batch_params) do
    case Events.create_batch(socket.assigns.current_scope, event, batch_params) do
      {:ok, batch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lote criado com sucesso.")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, batch)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp merge_extra_data(params, form_params) do
    rows = KeyValue.rows_from_params(params["extra_data"])
    {Map.put(form_params, "extra_data", KeyValue.to_map(rows)), rows}
  end

  defp cancel_path(:new, %{id: event_id}, _batch, _return_to),
    do: ~p"/batches?event_id=#{event_id}"

  defp cancel_path(:new, nil, _batch, _return_to), do: ~p"/batches"
  defp cancel_path(:edit, _event, _batch, "index"), do: ~p"/batches"
  defp cancel_path(:edit, _event, batch, _return_to), do: ~p"/batches/#{batch}"

  defp return_path(_scope, "show", %{id: nil}), do: ~p"/batches"
  defp return_path(_scope, "index", _batch), do: ~p"/batches"
  defp return_path(_scope, "show", batch), do: ~p"/batches/#{batch}"
end
