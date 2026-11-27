defmodule CertfyWeb.ParticipantLive.Show do
  use CertfyWeb, :live_view

  alias Certfy.{Certificates, Events}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:participants}>
      <.breadcrumb items={[
        %{label: "Participantes", navigate: ~p"/participants"},
        %{label: @event.name, navigate: ~p"/participants?event_id=#{@event.id}"},
        %{label: @batch.name, navigate: ~p"/participants?batch_id=#{@batch.id}"},
        %{label: @participant.name}
      ]} />
      <.header>
        {@participant.name}
        <:subtitle>Participante do lote {@batch.name} · {@event.name}.</:subtitle>

        <:actions>
          <.button
            navigate={~p"/participants?batch_id=#{@batch.id}"}
            aria-label="Voltar para participantes"
            variant="ghost"
          >
            <.icon name="hero-arrow-left" />
          </.button>

          <.button
            variant="primary"
            navigate={~p"/participants/#{@participant}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Editar participante
          </.button>
        </:actions>
      </.header>

      <.sheet>
        <.section title="Informações">
          <dl class="grid gap-4 sm:grid-cols-3">
            <div>
              <dt class="text-sm text-base-content/60">Nome</dt>

              <dd class="mt-1 text-base font-medium">{@participant.name}</dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">E-mail</dt>

              <dd class="mt-1 text-base">{@participant.email || "—"}</dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Atualizado em</dt>

              <dd class="mt-1 text-base">
                {Calendar.strftime(@participant.updated_at, "%d/%m/%Y às %H:%M")}
              </dd>
            </div>
          </dl>
        </.section>

        <.section title="Certificado" description="Gere o PDF, baixe ou envie por e-mail.">
          <%= if @certificate do %>
            <div class="flex flex-wrap items-center gap-3">
              <span class={["badge", certificate_badge_class(@certificate)]}>
                {certificate_label(@certificate)}
              </span>

              <p class="text-sm text-base-content/60">
                Código <span class="font-mono tracking-widest">{@certificate.code}</span>
              </p>

              <p :if={@certificate.generated_at} class="text-sm text-base-content/60">
                Gerado em {Calendar.strftime(@certificate.generated_at, "%d/%m/%Y às %H:%M")}
              </p>

              <p :if={@certificate.emailed_at} class="text-sm text-base-content/60">
                Enviado em {Calendar.strftime(@certificate.emailed_at, "%d/%m/%Y às %H:%M")}
              </p>
            </div>

            <p :if={@certificate.error} class="mt-3 text-sm text-error">
              {@certificate.error}
            </p>

            <p :if={@certificate.email_error} class="mt-3 text-sm text-error">
              {@certificate.email_error}
            </p>

            <div class="mt-4 flex flex-wrap gap-2">
              <.button
                :if={@certificate.status == :ready}
                href={~p"/certificates/#{@certificate}/download"}
                variant="primary"
              >
                <.icon name="hero-arrow-down-tray" /> Baixar PDF
              </.button>

              <button
                type="button"
                class="btn btn-soft"
                phx-click="generate_certificate"
                disabled={@certificate.status in [:pending, :processing]}
              >
                <.icon name="hero-arrow-path" /> Gerar novamente
              </button>

              <button
                type="button"
                class="btn btn-soft"
                phx-click="send_certificate"
                disabled={
                  @certificate.status != :ready or
                    is_nil(@participant.email) or @participant.email == ""
                }
              >
                <.icon name="hero-envelope" />
                {if @certificate.emailed_at, do: "Reenviar e-mail", else: "Enviar por e-mail"}
              </button>
            </div>

            <p
              :if={is_nil(@participant.email) or @participant.email == ""}
              class="mt-2 text-sm text-base-content/60"
            >
              Este participante não tem e-mail cadastrado.
            </p>
          <% else %>
            <p class="text-base text-base-content/70">
              Este participante ainda não tem certificado gerado.
            </p>

            <div class="mt-4">
              <button type="button" class="btn btn-primary" phx-click="generate_certificate">
                <.icon name="hero-document-arrow-down" /> Gerar certificado
              </button>
            </div>
          <% end %>
        </.section>

        <.section title="Dados adicionais">
          <.key_value_list id="participant-extra-data-list" data={@participant.extra_data} />
        </.section>

        <.section title="Contexto">
          <dl class="grid gap-4 sm:grid-cols-2">
            <div>
              <dt class="text-sm text-base-content/60">Evento</dt>

              <dd class="mt-1 text-base font-medium">
                <.link navigate={~p"/events/#{@event}"} class="link-hover">
                  {@event.name}
                </.link>
              </dd>
            </div>

            <div>
              <dt class="text-sm text-base-content/60">Lote</dt>

              <dd class="mt-1 text-base font-medium">
                <.link navigate={~p"/batches/#{@batch}"} class="link-hover">
                  {@batch.name}
                </.link>
              </dd>
            </div>
          </dl>
        </.section>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Events.subscribe_participants(socket.assigns.current_scope)
      Certificates.subscribe_certificates(socket.assigns.current_scope)
    end

    participant = Events.get_participant_with_context!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Participante")
     |> assign(:participant, participant)
     |> assign(:batch, participant.batch)
     |> assign(:event, participant.batch.event)
     |> assign_certificate()}
  end

  @impl true
  def handle_event("generate_certificate", _params, socket) do
    summary =
      Certificates.prepare_for_participants(socket.assigns.current_scope, [
        socket.assigns.participant.id
      ])

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
          put_flash(socket, :info, "Geração do certificado enfileirada.")
      end

    {:noreply, assign_certificate(socket)}
  end

  def handle_event("send_certificate", _params, socket) do
    summary =
      Certificates.send_emails(socket.assigns.current_scope, [socket.assigns.participant.id])

    socket =
      cond do
        summary.queued > 0 ->
          put_flash(socket, :info, "Envio do certificado enfileirado.")

        summary.no_email > 0 ->
          put_flash(socket, :error, "Este participante não tem e-mail cadastrado.")

        summary.not_ready > 0 ->
          put_flash(socket, :error, "Gere o certificado antes de enviar.")

        true ->
          put_flash(socket, :error, "Não foi possível enfileirar o envio.")
      end

    {:noreply, assign_certificate(socket)}
  end

  @impl true
  def handle_info(
        {:updated, %Certfy.Events.Participant{id: id} = participant},
        %{assigns: %{participant: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:participant, participant)
     |> assign_certificate()}
  end

  def handle_info(
        {:deleted, %Certfy.Events.Participant{id: id}},
        %{assigns: %{participant: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "O participante atual foi excluído.")
     |> push_navigate(to: ~p"/participants")}
  end

  def handle_info({type, %Certfy.Events.Participant{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  def handle_info({:certificate_updated, _certificate}, socket) do
    {:noreply, assign_certificate(socket)}
  end

  defp assign_certificate(socket) do
    assign(
      socket,
      :certificate,
      Certificates.get_certificate_for_participant(
        socket.assigns.current_scope,
        socket.assigns.participant.id
      )
    )
  end

  defp certificate_label(%{status: :pending}), do: "Gerando"
  defp certificate_label(%{status: :processing}), do: "Gerando"
  defp certificate_label(%{status: :failed}), do: "Erro"
  defp certificate_label(%{status: :ready, emailed_at: nil}), do: "Gerado"
  defp certificate_label(%{status: :ready}), do: "Enviado"

  defp certificate_badge_class(%{status: :pending}), do: "badge-warning"
  defp certificate_badge_class(%{status: :processing}), do: "badge-warning"
  defp certificate_badge_class(%{status: :failed}), do: "badge-error"
  defp certificate_badge_class(%{status: :ready, emailed_at: nil}), do: "badge-info"
  defp certificate_badge_class(%{status: :ready}), do: "badge-success"
end
