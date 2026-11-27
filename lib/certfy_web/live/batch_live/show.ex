defmodule CertfyWeb.BatchLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.{Certificates, Events}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.breadcrumb items={[
        %{label: "Eventos", navigate: ~p"/events"},
        %{label: @event.name, navigate: ~p"/events/#{@event}"},
        %{label: @batch.name}
      ]} />

      <.header>
        {@batch.name}
        <:subtitle>
          Lote do evento {@event.name} · {participant_count_label(@participant_count)}
        </:subtitle>

        <:actions>
          <.button variant="soft" navigate={~p"/batches/#{@batch}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Editar
          </.button>

          <.button
            :if={@participant_count > 0}
            variant="soft"
            navigate={~p"/participants/import?batch_id=#{@batch.id}"}
          >
            <.icon name="hero-table-cells" /> Importar planilha
          </.button>

          <.button
            :if={@participant_count > 0}
            variant="primary"
            navigate={~p"/participants/new?batch_id=#{@batch.id}"}
          >
            <.icon name="hero-plus" /> Adicionar participante
          </.button>
        </:actions>
      </.header>

      <.batch_tabs batch={@batch} active={:overview} participant_count={@participant_count} />

      <div class="space-y-4">
        <div
          :if={@participant_count == 0}
          class="rounded-box border border-primary/30 bg-primary/5 p-5 sm:p-6"
        >
          <p class="text-xs font-semibold uppercase tracking-wide text-primary">Próximo passo</p>
          <h2 class="mt-1 font-display text-xl font-semibold">Adicione os primeiros participantes</h2>
          <p class="mt-1 text-sm text-base-content/70">
            Cadastre uma pessoa por vez ou importe uma planilha CSV ou XLSX com várias de uma vez.
          </p>

          <div class="mt-4 flex flex-wrap gap-2">
            <.button variant="primary" navigate={~p"/participants/new?batch_id=#{@batch.id}"}>
              <.icon name="hero-plus" /> Adicionar participante
            </.button>

            <.button variant="soft" navigate={~p"/participants/import?batch_id=#{@batch.id}"}>
              <.icon name="hero-table-cells" /> Importar planilha
            </.button>
          </div>
        </div>

        <.sheet>
          <.section
            title="Certificados"
            description="Gere os PDFs deste lote e envie por e-mail aos participantes."
          >
            <div
              :if={@template_issue}
              class="mb-4 rounded-box border border-warning/40 bg-warning/10 p-4 text-sm"
              role="alert"
            >
              <p class="font-medium">{template_issue_message(@template_issue)}</p>
              <p class="mt-1 text-base-content/70">
                Configure o modelo no evento antes de gerar os certificados.
              </p>

              <.link
                navigate={~p"/events/#{@event}/template"}
                class="mt-2 inline-flex font-medium text-primary hover:underline"
              >
                Configurar modelo do evento
              </.link>
            </div>

            <dl class="grid gap-4 sm:grid-cols-4">
              <div>
                <dt class="text-sm text-base-content/60">Participantes</dt>
                <dd class="mt-1 text-base font-medium tabular-nums">{@certificate_stats.total}</dd>
              </div>
              <div>
                <dt class="text-sm text-base-content/60">Gerados</dt>
                <dd class="mt-1 text-base font-medium tabular-nums">
                  {@certificate_stats.generated}
                </dd>
              </div>
              <div>
                <dt class="text-sm text-base-content/60">Enviados</dt>
                <dd class="mt-1 text-base font-medium tabular-nums">{@certificate_stats.sent}</dd>
              </div>
              <div>
                <dt class="text-sm text-base-content/60">Em andamento</dt>
                <dd class="mt-1 text-base font-medium tabular-nums">
                  {@certificate_stats.pending}
                </dd>
              </div>
            </dl>

            <p :if={@certificate_stats.failed > 0} class="mt-3 text-sm text-error">
              {@certificate_stats.failed} certificado(s) com erro.
            </p>

            <p :if={@certificate_stats.no_email > 0} class="mt-1 text-sm text-base-content/60">
              {@certificate_stats.no_email} participante(s) sem e-mail.
            </p>

            <div class="mt-4 flex flex-wrap gap-2">
              <button
                type="button"
                class="btn btn-primary"
                phx-click="generate_batch_certificates"
                disabled={@certificate_stats.total == 0 or not is_nil(@template_issue)}
              >
                <.icon name="hero-document-arrow-down" /> Gerar certificados
              </button>

              <button
                type="button"
                class="btn btn-soft"
                phx-click="send_batch_certificates"
                disabled={@certificate_stats.generated == 0}
              >
                <.icon name="hero-envelope" /> Enviar por e-mail
              </button>
            </div>
          </.section>
        </.sheet>

        <.sheet>
          <.section title="Sobre o lote">
            <dl class="grid gap-4 sm:grid-cols-2">
              <div>
                <dt class="text-sm text-base-content/60">Evento</dt>
                <dd class="mt-1 text-base font-medium">
                  <.link navigate={~p"/events/#{@event}"} class="hover:underline">
                    {@event.name}
                  </.link>
                </dd>
              </div>

              <div>
                <dt class="text-sm text-base-content/60">Atualizado em</dt>
                <dd class="mt-1 text-base">
                  {Calendar.strftime(@batch.updated_at, "%d/%m/%Y às %H:%M")}
                </dd>
              </div>
            </dl>
          </.section>
        </.sheet>

        <details
          :if={map_size(@batch.extra_data) > 0}
          class="rounded-box border border-base-300 bg-base-100"
        >
          <summary class="cursor-pointer px-5 py-4 font-medium">
            Dados adicionais ({map_size(@batch.extra_data)})
          </summary>

          <div class="border-t border-base-300 p-5">
            <.key_value_list id="batch-extra-data-list" data={@batch.extra_data} />
          </div>
        </details>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      scope = socket.assigns.current_scope
      Events.subscribe_batches(scope)
      Events.subscribe_participants(scope)
      Certificates.subscribe_certificates(scope)
    end

    batch = Events.get_batch_with_event!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Lote")
     |> assign(:reload_scheduled, false)
     |> assign_batch_data(batch)}
  end

  @impl true
  def handle_event("generate_batch_certificates", _params, socket) do
    summary =
      Certificates.prepare_for_batch(socket.assigns.current_scope, socket.assigns.batch.id)

    socket =
      cond do
        summary.no_template > 0 ->
          put_flash(socket, :error, "O evento não possui um modelo de certificado.")

        summary.invalid_template > 0 ->
          put_flash(
            socket,
            :error,
            "O modelo possui tags malformadas. Corrija e envie novamente."
          )

        true ->
          put_flash(socket, :info, "#{summary.queued} certificado(s) enfileirado(s).")
      end

    {:noreply, assign_certificate_stats(socket)}
  end

  def handle_event("send_batch_certificates", _params, socket) do
    summary =
      Certificates.send_emails_for_batch(socket.assigns.current_scope, socket.assigns.batch.id)

    socket =
      if summary.queued > 0 do
        put_flash(socket, :info, "#{summary.queued} e-mail(s) enfileirado(s).")
      else
        put_flash(socket, :error, "Nenhum certificado pronto com e-mail para enviar.")
      end

    {:noreply, assign_certificate_stats(socket)}
  end

  @impl true
  def handle_info(
        {:deleted, %Certfy.Events.Batch{id: id}},
        %{assigns: %{batch: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "O lote atual foi excluído.")
     |> push_navigate(to: ~p"/batches")}
  end

  def handle_info({type, %Certfy.Events.Batch{}}, socket)
      when type in [:created, :updated] do
    batch = Events.get_batch_with_event!(socket.assigns.current_scope, socket.assigns.batch.id)
    {:noreply, assign_batch_data(socket, batch)}
  end

  def handle_info({type, _record}, socket) when type in [:created, :updated, :deleted] do
    {:noreply,
     assign_certificate_stats(
       assign(
         socket,
         :participant_count,
         Events.count_participants(socket.assigns.current_scope, socket.assigns.batch)
       )
     )}
  end

  def handle_info({:certificate_updated, _certificate}, socket) do
    if socket.assigns.reload_scheduled do
      {:noreply, socket}
    else
      Process.send_after(self(), :reload_certificates, 800)
      {:noreply, assign(socket, :reload_scheduled, true)}
    end
  end

  def handle_info(:reload_certificates, socket) do
    {:noreply,
     socket
     |> assign(:reload_scheduled, false)
     |> assign_certificate_stats()}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp assign_batch_data(socket, batch) do
    socket
    |> assign(:batch, batch)
    |> assign(:event, batch.event)
    |> assign(
      :participant_count,
      Events.count_participants(socket.assigns.current_scope, batch)
    )
    |> assign(:template_issue, template_issue(batch.event))
    |> assign_certificate_stats()
  end

  defp assign_certificate_stats(socket) do
    assign(
      socket,
      :certificate_stats,
      Certificates.batch_stats(socket.assigns.current_scope, socket.assigns.batch.id)
    )
  end

  defp template_issue(%{template_path: nil}), do: :missing

  defp template_issue(%{template_report: report}) when is_map(report) do
    if (report["malformed"] || []) == [], do: nil, else: :malformed
  end

  defp template_issue(_event), do: nil

  defp template_issue_message(:missing), do: "O evento ainda não tem modelo de certificado."
  defp template_issue_message(:malformed), do: "O modelo do evento tem tags malformadas."

  defp participant_count_label(1), do: "1 participante"
  defp participant_count_label(total), do: "#{total} participantes"
end
