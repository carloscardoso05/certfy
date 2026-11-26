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
        <:subtitle>Use this form to manage batch records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="batch-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Batch</.button>
          <.button navigate={return_path(@current_scope, @return_to, @batch)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"event_id" => event_id} = params, _session, socket) do
    event = Events.get_event!(socket.assigns.current_scope, event_id)

    {:ok,
     socket
     |> assign(:event, event)
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    batch = Events.get_batch!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Batch")
    |> assign(:batch, batch)
    |> assign(:form, to_form(Events.change_batch(socket.assigns.current_scope, batch)))
  end

  defp apply_action(socket, :new, _params) do
    batch = %Batch{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Batch")
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
         |> put_flash(:info, "Batch updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, batch)
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
         |> put_flash(:info, "Batch created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, batch)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _batch), do: ~p"/batches"
  defp return_path(_scope, "show", batch), do: ~p"/batches/#{batch}"
end
