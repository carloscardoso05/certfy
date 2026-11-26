defmodule CertfyWeb.ParticipantLive.Form do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Participant

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>
          Use este formulário para gerenciar os participantes do seu banco de dados.
        </:subtitle>
      </.header>

      <.form for={@form} id="participant-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Nome" />
        <.input field={@form[:email]} type="text" label="E-mail" />
        <footer>
          <.button phx-disable-with="Salvando..." variant="primary">Salvar participante</.button>
          <.button navigate={return_path(@current_scope, @event, @batch, @return_to, @participant)}>
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
    participant =
      Events.get_participant!(socket.assigns.current_scope, socket.assigns.batch, id)

    socket
    |> assign(:page_title, "Editar participante")
    |> assign(:participant, participant)
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
    |> assign(
      :form,
      to_form(Events.change_participant(socket.assigns.current_scope, participant))
    )
  end

  @impl true
  def handle_event("validate", %{"participant" => participant_params}, socket) do
    changeset =
      Events.change_participant(
        socket.assigns.current_scope,
        socket.assigns.participant,
        participant_params
      )

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"participant" => participant_params}, socket) do
    save_participant(socket, socket.assigns.live_action, participant_params)
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
