defmodule CertfyWeb.BatchLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.{Certificates, Events}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:batches}>
      <.breadcrumb items={[
        %{label: "Lotes", navigate: ~p"/batches"},
        %{label: @event.name, navigate: ~p"/batches?event_id=#{@event.id}"},
        %{label: @batch.name}
      ]} />
      <.header>
        {@batch.name}
        <:subtitle>Lote #{@batch.id} do evento {@event.name}.</:subtitle>

        <:actions>
          <.button navigate={~p"/batches"} aria-label="Voltar para lotes" variant="ghost">
            <.icon name="hero-arrow-left" />
          </.button>

          <.button navigate={~p"/participants?batch_id=#{@batch.id}"} variant="soft">
            <.icon name="hero-users" /> Participantes
          </.button>

          <.button variant="primary" navigate={~p"/batches/#{@batch}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Editar lote
          </.button>
        </:actions>
      </.header>

      <.sheet>
        <.section title="Informações">
          <dl class="grid gap-4 sm:grid-cols-3">
            <div>
              <dt class="text-sm text-base-content/60">Nome</dt>

              <dd class="mt-1 text-base font-medium">{@batch.name}</dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Evento</dt>

              <dd class="mt-1 text-base font-medium">
                <.link navigate={~p"/events/#{@event}"} class="link-hover">
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

        <.section title="Dados adicionais">
          <.key_value_list id="batch-extra-data-list" data={@batch.extra_data} />
        </.section>

        <.section
          title="Certificados"
          description="Gere os PDFs deste lote e envie por e-mail."
        >
          <dl class="grid gap-4 sm:grid-cols-4">
            <div>
              <dt class="text-sm text-base-content/60">Participantes</dt>
              <dd class="mt-1 text-base font-medium tabular-nums">{@certificate_stats.total}</dd>
            </div>
            <div>
              <dt class="text-sm text-base-content/60">Gerados</dt>
              <dd class="mt-1 text-base font-medium tabular-nums">{@certificate_stats.generated}</dd>
            </div>
            <div>
              <dt class="text-sm text-base-content/60">Enviados</dt>
              <dd class="mt-1 text-base font-medium tabular-nums">{@certificate_stats.sent}</dd>
            </div>
            <div>
              <dt class="text-sm text-base-content/60">Em andamento</dt>
              <dd class="mt-1 text-base font-medium tabular-nums">{@certificate_stats.pending}</dd>
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
              disabled={@certificate_stats.total == 0}
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

        <.section
          title="Participantes"
          description={"#{participant_count_label(@participant_count)} neste lote."}
        >
          <.button navigate={~p"/participants?batch_id=#{@batch.id}"} variant="soft">
            <.icon name="hero-users" /> Abrir participantes
          </.button>
        </.section>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_batches(socket.assigns.current_scope)
      Certificates.subscribe_certificates(socket.assigns.current_scope)
    end

    batch = Events.get_batch_with_event!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Lote")
     |> assign(:batch, batch)
     |> assign(:event, batch.event)
     |> assign(
       :participant_count,
       Events.count_participants(socket.assigns.current_scope, batch)
     )
     |> assign(:reload_scheduled, false)
     |> assign_certificate_stats()}
  end

  @impl true
  def handle_event("generate_batch_certificates", _params, socket) do
    summary =
      Certificates.prepare_for_batch(socket.assigns.current_scope, socket.assigns.batch.id)

    socket =
      cond do
        summary.no_template > 0 ->
          put_flash(socket, :error, "O evento não possui um template de certificado.")

        summary.invalid_template > 0 ->
          put_flash(
            socket,
            :error,
            "O template possui tags malformadas. Corrija e envie novamente."
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
        {:updated, %Certfy.Events.Batch{id: id} = batch},
        %{assigns: %{batch: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :batch, batch)}
  end

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
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
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

  defp assign_certificate_stats(socket) do
    assign(
      socket,
      :certificate_stats,
      Certificates.batch_stats(socket.assigns.current_scope, socket.assigns.batch.id)
    )
  end

  defp participant_count_label(1), do: "1 participante"
  defp participant_count_label(total), do: "#{total} participantes"
end
