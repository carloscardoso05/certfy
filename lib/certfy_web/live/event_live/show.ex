defmodule CertfyWeb.EventLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Batch

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.breadcrumb items={[
        %{label: "Eventos", navigate: ~p"/events"},
        %{label: @event.name}
      ]} />

      <.header>
        {@event.name}
        <:subtitle>
          Evento · {batch_count_label(@batch_count)} · {participant_count_label(@participant_count)} · atualizado em {Calendar.strftime(
            @event.updated_at,
            "%d/%m/%Y"
          )}
        </:subtitle>

        <:actions>
          <.button variant="soft" navigate={~p"/events/#{@event}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Editar
          </.button>

          <.button variant="primary" phx-click="open_batch_modal">
            <.icon name="hero-plus" /> Novo lote
          </.button>
        </:actions>
      </.header>

      <.event_tabs
        event={@event}
        active={:overview}
        batch_count={@batch_count}
        participant_count={@participant_count}
      />

      <div class="space-y-4">
        <div class="rounded-box border border-primary/30 bg-primary/5 p-5 sm:p-6">
          <div class="flex flex-wrap items-start gap-4">
            <span class="flex size-11 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
              <.icon name={@next_step.icon} class="size-5" />
            </span>

            <div class="min-w-0 flex-1">
              <p class="text-xs font-semibold uppercase tracking-wide text-primary">Próximo passo</p>
              <h2 class="mt-1 font-display text-xl font-semibold">{@next_step.title}</h2>
              <p class="mt-1 text-sm text-base-content/70">{@next_step.description}</p>
            </div>

            <div class="w-full sm:w-auto">
              <.button variant="primary" navigate={@next_step.path}>
                {@next_step.label}
              </.button>
            </div>
          </div>
        </div>

        <div class="grid gap-4 lg:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)]">
          <.sheet>
            <.section
              title="Lotes"
              description="Um lote é uma turma, dia ou categoria dentro do evento."
            >
              <.empty_state
                :if={@batches == []}
                title="Nenhum lote ainda"
                description="Crie o primeiro lote para começar a cadastrar participantes."
              >
                <:action>
                  <.button variant="primary" phx-click="open_batch_modal">
                    <.icon name="hero-plus" /> Criar primeiro lote
                  </.button>
                </:action>
              </.empty_state>

              <ul :if={@batches != []} class="divide-y divide-base-300">
                <li
                  :for={batch <- @batches}
                  class="flex flex-wrap items-center gap-3 py-3 first:pt-0 last:pb-0"
                >
                  <div class="min-w-0 flex-1">
                    <.link navigate={~p"/batches/#{batch}"} class="font-medium hover:underline">
                      {batch.name}
                    </.link>
                    <p class="text-sm text-base-content/60">
                      {participant_count_label(batch.participants_count)}
                    </p>
                  </div>

                  <.link
                    navigate={~p"/participants?batch_id=#{batch.id}"}
                    class="btn btn-soft btn-sm"
                  >
                    Participantes
                  </.link>

                  <.link navigate={~p"/batches/#{batch}"} class="btn btn-ghost btn-sm">
                    Abrir
                  </.link>
                </li>
              </ul>

              <div :if={@batches != []} class="mt-4 border-t border-base-300 pt-4">
                <.link
                  navigate={~p"/batches?event_id=#{@event.id}"}
                  class="text-sm font-medium text-primary hover:underline"
                >
                  Ver todos os {@batch_count} lotes
                </.link>
              </div>
            </.section>
          </.sheet>

          <.sheet>
            <.section
              title="Modelo do certificado"
              description="Arquivo .pptx usado para gerar os certificados deste evento."
            >
              <div class="flex flex-wrap items-center gap-2">
                <span class={["badge", template_badge_class(@event)]}>
                  {template_label(@event)}
                </span>
                <p class="text-sm text-base-content/60">{template_hint(@event)}</p>
              </div>

              <div class="mt-4 flex flex-wrap gap-2">
                <.button
                  variant="soft"
                  navigate={~p"/events/#{@event}/template"}
                >
                  <.icon name="hero-rectangle-group" />
                  {if @event.template_path, do: "Gerenciar modelo", else: "Abrir modelo"}
                </.button>

                <.button
                  :if={@event.template_path}
                  href={~p"/events/#{@event}/template/download"}
                  variant="ghost"
                >
                  <.icon name="hero-arrow-down-tray" /> Baixar
                </.button>
              </div>
            </.section>
          </.sheet>
        </div>

        <details
          :if={map_size(@event.extra_data) > 0}
          class="rounded-box border border-base-300 bg-base-100"
        >
          <summary class="cursor-pointer px-5 py-4 font-medium">
            Dados adicionais ({map_size(@event.extra_data)})
          </summary>

          <div class="border-t border-base-300 p-5">
            <.key_value_list id="event-extra-data-list" data={@event.extra_data} />
          </div>
        </details>
      </div>

      <.modal
        :if={@modal == :new_batch}
        id="batch-modal"
        title="Novo lote"
        description="Um lote é uma turma, dia ou categoria dentro do evento. Dados adicionais podem ser incluídos depois em Editar lote."
      >
        <.form
          for={@batch_form}
          id="modal-batch-form"
          phx-change="validate_batch"
          phx-submit="create_batch"
          class="space-y-3"
        >
          <.input field={@batch_form[:name]} type="text" label="Nome" required />

          <div class="flex justify-end gap-2">
            <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancelar</button>
            <.button variant="primary" phx-disable-with="Criando...">Criar lote</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      scope = socket.assigns.current_scope
      Events.subscribe_events(scope)
      Events.subscribe_batches(scope)
      Events.subscribe_participants(scope)
    end

    event = Events.get_event!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Evento")
     |> assign(:modal, nil)
     |> assign(:batch_form, to_form(%{}))
     |> assign_event_data(event)}
  end

  @impl true
  def handle_event("open_batch_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal, :new_batch)
     |> assign(:batch_form, to_form(batch_changeset(socket, %{})))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :modal, nil)}
  end

  def handle_event("validate_batch", %{"batch" => params}, socket) do
    form =
      socket
      |> batch_changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :batch_form, form)}
  end

  def handle_event("create_batch", %{"batch" => params}, socket) do
    case Events.create_batch(socket.assigns.current_scope, socket.assigns.event, params) do
      {:ok, batch} ->
        {:noreply,
         socket
         |> assign(:modal, nil)
         |> put_flash(:info, "Lote #{batch.name} criado.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :batch_form, to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def handle_info(
        {:deleted, %Certfy.Events.Event{id: id}},
        %{assigns: %{event: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "O evento atual foi excluído.")
     |> push_navigate(to: ~p"/events")}
  end

  def handle_info(
        {:updated, %Certfy.Events.Event{id: id} = event},
        %{assigns: %{event: %{id: id}}} = socket
      ) do
    {:noreply, assign_event_data(socket, event)}
  end

  def handle_info({type, _record}, socket) when type in [:created, :updated, :deleted] do
    {:noreply, assign_event_data(socket, socket.assigns.event)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp assign_event_data(socket, event) do
    scope = socket.assigns.current_scope

    result =
      Events.list_batches_page(scope, %{
        "event_id" => event.id,
        "page" => "1"
      })

    batches = Enum.take(result.items, 5)
    participant_count = Events.count_participants_for_event(scope, event)
    first_batch = List.first(result.items)

    socket
    |> assign(:event, event)
    |> assign(:batches, batches)
    |> assign(:batch_count, result.total)
    |> assign(:participant_count, participant_count)
    |> assign(:first_batch, first_batch)
    |> assign(:next_step, next_step(event, result.total, participant_count, first_batch))
  end

  defp batch_changeset(socket, params) do
    event = socket.assigns.event

    %Batch{user_id: event.user_id, event_id: event.id}
    |> Batch.changeset(params, socket.assigns.current_scope)
  end

  defp next_step(event, batch_count, participant_count, first_batch) do
    cond do
      is_nil(event.template_path) ->
        %{
          title: "Envie o modelo do certificado",
          description:
            "O modelo .pptx define o visual dos certificados e as tags que serão preenchidas.",
          label: "Enviar modelo",
          path: ~p"/events/#{event}/template",
          icon: "hero-document-plus"
        }

      malformed?(event) ->
        %{
          title: "Corrija as tags do modelo",
          description:
            "O modelo enviado tem tags malformadas. A geração fica bloqueada até o arquivo ser corrigido.",
          label: "Revisar modelo",
          path: ~p"/events/#{event}/template",
          icon: "hero-exclamation-triangle"
        }

      batch_count == 0 ->
        %{
          title: "Crie o primeiro lote",
          description:
            "Os participantes são organizados por lote. Crie um para começar a cadastrar pessoas.",
          label: "Criar lote",
          path: ~p"/batches/new?event_id=#{event.id}",
          icon: "hero-plus"
        }

      participant_count == 0 and not is_nil(first_batch) ->
        %{
          title: "Adicione participantes ao lote #{first_batch.name}",
          description: "Cadastre manualmente ou importe uma planilha CSV ou XLSX para este lote.",
          label: "Ver participantes",
          path: ~p"/participants?batch_id=#{first_batch.id}",
          icon: "hero-user-plus"
        }

      true ->
        path =
          if first_batch do
            ~p"/batches/#{first_batch}"
          else
            ~p"/batches?event_id=#{event.id}"
          end

        %{
          title: "Gere os certificados",
          description:
            "Abra um lote para gerar os PDFs e enviar por e-mail aos participantes que têm e-mail.",
          label: "Ver lotes",
          path: path,
          icon: "hero-document-arrow-down"
        }
    end
  end

  defp malformed?(%{template_report: report}), do: malformed?(report)
  defp malformed?(report) when is_map(report), do: (report["malformed"] || []) != []
  defp malformed?(_report), do: false

  defp template_label(%{template_path: nil}), do: "Pendente"

  defp template_label(%{template_report: report}) when is_map(report) do
    if malformed?(report), do: "Corrigir tags", else: "Enviado"
  end

  defp template_label(_event), do: "Enviado"

  defp template_badge_class(%{template_path: nil}), do: "badge-ghost"

  defp template_badge_class(%{template_report: report}) when is_map(report) do
    if malformed?(report), do: "badge-error", else: "badge-success"
  end

  defp template_badge_class(_event), do: "badge-success"

  defp template_hint(%{template_path: nil}), do: "Envie o arquivo para liberar a geração."

  defp template_hint(%{template_report: report}) when is_map(report) do
    if malformed?(report), do: "Corrija as tags e envie novamente.", else: "Pronto para usar."
  end

  defp template_hint(_event), do: "Pronto para usar."

  defp batch_count_label(1), do: "1 lote"
  defp batch_count_label(total), do: "#{total} lotes"

  defp participant_count_label(1), do: "1 participante"
  defp participant_count_label(total), do: "#{total} participantes"
end
