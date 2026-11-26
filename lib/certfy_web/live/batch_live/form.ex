defmodule CertfyWeb.BatchLive.Form do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Batch

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Use este formulário para gerenciar os lotes do seu banco de dados.</:subtitle>
      </.header>

      <.form for={@form} id="batch-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Nome" />
        <footer>
          <.button phx-disable-with="Salvando..." variant="primary">Salvar lote</.button>
          <.button navigate={return_path(@current_scope, @event, @return_to, @batch)}>
            Cancelar
          </.button>
        </footer>
      </.form>
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
    batch = Events.get_batch!(socket.assigns.current_scope, socket.assigns.event, id)

    socket
    |> assign(:page_title, "Editar lote")
    |> assign(:batch, batch)
    |> assign(:form, to_form(Events.change_batch(socket.assigns.current_scope, batch)))
  end

  defp apply_action(socket, :new, _params) do
    batch = %Batch{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "Novo lote")
    |> assign(:batch, batch)
    |> assign(:form, to_form(Events.change_batch(socket.assigns.current_scope, batch)))
  end

  @impl true
  def handle_event("validate", %{"batch" => batch_params}, socket) do
    changeset =
      Events.change_batch(socket.assigns.current_scope, socket.assigns.batch, batch_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"batch" => batch_params}, socket) do
    save_batch(socket, socket.assigns.live_action, batch_params)
  end

  defp save_batch(socket, :edit, batch_params) do
    case Events.update_batch(socket.assigns.current_scope, socket.assigns.batch, batch_params) do
      {:ok, batch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lote atualizado com sucesso.")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.event,
               socket.assigns.return_to,
               batch
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_batch(socket, :new, batch_params) do
    case Events.create_batch(socket.assigns.current_scope, socket.assigns.event, batch_params) do
      {:ok, batch} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lote criado com sucesso.")
         |> push_navigate(
           to:
             return_path(
               socket.assigns.current_scope,
               socket.assigns.event,
               socket.assigns.return_to,
               batch
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, event, "index", _batch), do: ~p"/events/#{event}/batches"
  defp return_path(_scope, event, "show", batch), do: ~p"/events/#{event}/batches/#{batch}"
end
