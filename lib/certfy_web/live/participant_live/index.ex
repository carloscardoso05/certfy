defmodule CertfyWeb.ParticipantLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.{Certificates, Events}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:participants}>
      <.breadcrumb
        :if={@context_batch}
        items={[
          %{label: "Eventos", navigate: ~p"/events"},
          %{label: @context_event.name, navigate: ~p"/events/#{@context_event}"},
          %{label: @context_batch.name, navigate: ~p"/batches/#{@context_batch}"},
          %{label: "Participantes"}
        ]}
      />

      <.breadcrumb
        :if={is_nil(@context_batch) and @context_event}
        items={[
          %{label: "Eventos", navigate: ~p"/events"},
          %{label: @context_event.name, navigate: ~p"/events/#{@context_event}"},
          %{label: "Participantes"}
        ]}
      />

      <.header>
        {context_title(@context_batch, @context_event)}
        <:subtitle>{context_subtitle(@context_batch, @context_event)}</:subtitle>

        <:actions>
          <.button variant="soft" navigate={import_path(@context_batch)}>
            <.icon name="hero-table-cells" /> Importar planilha
          </.button>

          <.button variant="primary" navigate={new_participant_path(@context_batch)}>
            <.icon name="hero-plus" /> Novo participante
          </.button>
        </:actions>
      </.header>

      <.event_tabs
        :if={@context_event}
        event={@context_event}
        active={:participants}
        batch_count={@context_batch_count}
        participant_count={@context_participant_count}
      />

      <.form for={@filter_form} id="participant-filters" phx-change="filter" class="mb-4">
        <input
          :if={@context_batch}
          type="hidden"
          name="event_id"
          value={@context_event.id}
        />

        <input
          :if={@context_batch}
          type="hidden"
          name="batch_id"
          value={@context_batch.id}
        />

        <input
          :if={is_nil(@context_batch) and @context_event}
          type="hidden"
          name="event_id"
          value={@context_event.id}
        />

        <div class={[
          "grid gap-3 md:items-end",
          cond do
            @context_batch -> "md:grid-cols-[minmax(0,1fr)_12rem]"
            @context_event -> "md:grid-cols-[minmax(0,1fr)_15rem_12rem]"
            true -> "md:grid-cols-[minmax(0,1fr)_14rem_15rem_12rem]"
          end
        ]}>
          <label class="block">
            <span class="mb-1 block text-sm font-medium">Buscar</span>
            <span class="input input-bordered flex w-full items-center gap-2">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-60" />
              <input
                type="search"
                name="q"
                value={@filters["q"]}
                placeholder="Nome ou e-mail"
                class="grow"
                phx-debounce="300"
              />
            </span>
          </label>

          <.searchable_select
            :if={is_nil(@context_event)}
            id="participant-filter-event"
            name="event_id"
            label="Evento"
            label_class="mb-1 block text-sm font-medium"
            placeholder="Todos"
            options={@event_options}
            selected={@filters["event_id"]}
            class="w-full"
          />

          <.searchable_select
            :if={is_nil(@context_batch)}
            id="participant-filter-batch"
            name="batch_id"
            label="Lote"
            label_class="mb-1 block text-sm font-medium"
            placeholder="Todos"
            options={@batch_options}
            selected={@filters["batch_id"]}
            class="w-full"
          />

          <label class="block">
            <span class="mb-1 block text-sm font-medium">Certificado</span>
            <select name="certificate" class="select select-bordered w-full">
              <option value="" selected={@filters["certificate"] == ""}>Todos</option>
              <option value="none" selected={@filters["certificate"] == "none"}>Não gerado</option>
              <option value="ready" selected={@filters["certificate"] == "ready"}>Gerado</option>
              <option value="sent" selected={@filters["certificate"] == "sent"}>Enviado</option>
              <option value="error" selected={@filters["certificate"] == "error"}>Com erro</option>
              <option value="no_email" selected={@filters["certificate"] == "no_email"}>
                Sem e-mail
              </option>
            </select>
          </label>
        </div>
      </.form>

      <div class="mb-4 flex flex-wrap items-center gap-2">
        <button type="button" class="btn btn-soft btn-sm" phx-click="select_all">
          Selecionar todos ({@selection_counts.all})
        </button>
        <button type="button" class="btn btn-soft btn-sm" phx-click="select_not_generated">
          Não gerados ({@selection_counts.not_generated})
        </button>
        <button type="button" class="btn btn-soft btn-sm" phx-click="select_not_sent">
          Não enviados ({@selection_counts.not_sent})
        </button>
        <button type="button" class="btn btn-soft btn-sm" phx-click="select_error">
          Com erro ({@selection_counts.error})
        </button>
        <button type="button" class="btn btn-soft btn-sm" phx-click="select_no_email">
          Sem e-mail ({@selection_counts.no_email})
        </button>

        <button
          :if={MapSet.size(@selected) > 0}
          type="button"
          class="btn btn-ghost btn-sm"
          phx-click="clear_selection"
        >
          Limpar seleção
        </button>
      </div>

      <div
        :if={MapSet.size(@selected) > 0}
        id="bulk-actions"
        class="mb-4 flex flex-wrap items-center gap-2 rounded-box border border-primary/30 bg-primary/5 p-3"
      >
        <p class="text-sm font-medium">
          {MapSet.size(@selected)} selecionado(s)
        </p>

        <div class="flex-1"></div>

        <button
          type="button"
          class="btn btn-primary btn-sm"
          phx-click="bulk_generate"
          data-confirm={generate_confirm(@selected_summary)}
        >
          <.icon name="hero-document-arrow-down" /> Gerar certificados
        </button>

        <button
          type="button"
          class="btn btn-soft btn-sm"
          phx-click="bulk_send"
          data-confirm={send_confirm(@selected_summary)}
        >
          <.icon name="hero-envelope" /> Enviar por e-mail
        </button>
      </div>

      <div :if={@empty?}>
        <.empty_state
          title={
            cond do
              @has_filters? -> "Nenhum participante encontrado"
              @context_batch -> "Nenhum participante neste lote"
              @context_event -> "Nenhum participante neste evento"
              true -> "Nenhum participante ainda"
            end
          }
          description={
            cond do
              @has_filters? -> "Ajuste a busca ou os filtros de certificado."
              @context_batch -> "Adicione manualmente ou importe uma planilha CSV ou XLSX."
              @context_event -> "Abra um lote para adicionar participantes ou importe uma planilha."
              true -> "Abra um lote para cadastrar o primeiro participante."
            end
          }
        >
          <:action>
            <div class="flex flex-wrap items-center justify-center gap-2">
              <.link
                :if={@has_filters?}
                patch={clear_filters_path(@context_batch, @context_event)}
                class="btn btn-ghost btn-sm"
              >
                Limpar filtros
              </.link>

              <.button
                :if={!@has_filters?}
                variant="primary"
                navigate={new_participant_path(@context_batch)}
              >
                <.icon name="hero-plus" /> Novo participante
              </.button>

              <.button :if={!@has_filters?} variant="soft" navigate={import_path(@context_batch)}>
                <.icon name="hero-table-cells" /> Importar planilha
              </.button>

              <.button
                :if={!@has_filters? and is_nil(@context_batch)}
                variant="ghost"
                navigate={batches_path(@context_event)}
              >
                <.icon name="hero-rectangle-stack" /> Ver lotes
              </.button>
            </div>
          </:action>
        </.empty_state>
      </div>

      <div :if={!@empty?} class="overflow-hidden rounded-box border border-base-300 bg-base-100">
        <div class={[
          "hidden gap-4 border-b border-base-300 px-4 py-3 text-sm font-medium text-base-content/70 md:grid",
          if(@context_batch,
            do: "grid-cols-[2.5rem_minmax(0,1fr)_minmax(0,1fr)_9rem_13rem]",
            else: "grid-cols-[2.5rem_minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_9rem_13rem]"
          )
        ]}>
          <input
            type="checkbox"
            class="checkbox checkbox-sm"
            checked={@page_all_selected?}
            phx-click="toggle_page"
            aria-label="Selecionar página"
          />
          <span>Nome</span> <span>E-mail</span>
          <span :if={is_nil(@context_batch)}>Evento / lote</span>
          <span>Certificado</span>
          <span class="text-right">Ações</span>
        </div>

        <div id="participants" phx-update="stream">
          <div
            :for={{id, participant} <- @streams.participants}
            id={id}
            class={[
              "relative grid grid-cols-1 gap-2 border-b border-base-300 px-4 py-4 last:border-0 hover:bg-base-200/60 md:items-center md:gap-4",
              if(@context_batch,
                do: "md:grid-cols-[2.5rem_minmax(0,1fr)_minmax(0,1fr)_9rem_13rem]",
                else: "md:grid-cols-[2.5rem_minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_9rem_13rem]"
              )
            ]}
          >
            <.link
              navigate={~p"/participants/#{participant}"}
              class="absolute inset-0 z-0 rounded-box focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
              aria-label={"Abrir #{participant.name}"}
            ></.link>

            <div class="relative z-10">
              <input
                type="checkbox"
                class="checkbox checkbox-sm"
                checked={MapSet.member?(@selected, participant.id)}
                phx-click="toggle_select"
                phx-value-id={participant.id}
                aria-label={"Selecionar #{participant.name}"}
              />
            </div>

            <div class="min-w-0">
              <p class="truncate text-base font-medium">{participant.name}</p>

              <p class="truncate text-sm text-base-content/60 md:hidden">
                {participant.email || "Sem e-mail"}
              </p>
            </div>

            <div class="hidden min-w-0 text-sm text-base-content/70 md:block">
              <span class="truncate">{participant.email || "—"}</span>
            </div>

            <div :if={is_nil(@context_batch)} class="min-w-0 text-sm text-base-content/70">
              <p class="truncate">{participant.batch.event.name}</p>

              <p class="truncate text-xs">{participant.batch.name}</p>
            </div>

            <div class="text-sm">
              <span class={["badge badge-sm", certificate_badge_class(participant.certificate)]}>
                {certificate_label(participant.certificate)}
              </span>

              <p
                :if={is_nil(participant.email) or participant.email == ""}
                class="mt-1 text-xs text-base-content/60"
              >
                Sem e-mail
              </p>
            </div>

            <div class="relative z-10 flex flex-wrap justify-end gap-2">
              <.link navigate={~p"/participants/#{participant}/edit"} class="btn btn-soft">
                Editar
              </.link>

              <button
                type="button"
                class="btn btn-soft btn-error"
                phx-click={JS.push("delete", value: %{id: participant.id})}
                data-confirm="Tem certeza que deseja excluir este participante?"
              >
                Excluir
              </button>
            </div>
          </div>
        </div>
      </div>

      <div :if={!@empty?} class="mt-4 flex flex-wrap items-center justify-between gap-2">
        <p class="text-sm text-base-content/60">
          {count_label(@page_info.total)} · página {@page_info.page} de {@page_info.pages}
        </p>

        <div class="join">
          <%= if @page_info.page > 1 do %>
            <.link patch={page_path(@filters, @page_info.page - 1)} class="btn join-item">
              Anterior
            </.link>
          <% else %>
            <button type="button" class="btn join-item btn-disabled" disabled>Anterior</button>
          <% end %>

          <%= if @page_info.page < @page_info.pages do %>
            <.link patch={page_path(@filters, @page_info.page + 1)} class="btn join-item">
              Próxima
            </.link>
          <% else %>
            <button type="button" class="btn join-item btn-disabled" disabled>Próxima</button>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Events.subscribe_participants(socket.assigns.current_scope)
      Certificates.subscribe_certificates(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Participantes")
     |> assign(:filters, %{
       "q" => "",
       "event_id" => "",
       "batch_id" => "",
       "certificate" => "",
       "page" => 1
     })
     |> assign(
       :filter_form,
       to_form(%{
         "q" => "",
         "event_id" => "",
         "batch_id" => "",
         "certificate" => ""
       })
     )
     |> assign(:page_info, %{items: [], total: 0, page: 1, pages: 1})
     |> assign(:empty?, true)
     |> assign(:has_filters?, false)
     |> assign(:context_batch, nil)
     |> assign(:context_event, nil)
     |> assign(:context_batch_count, nil)
     |> assign(:context_participant_count, nil)
     |> assign(:selected, MapSet.new())
     |> assign(:page_ids, [])
     |> assign(:page_all_selected?, false)
     |> assign(:selected_summary, zero_summary())
     |> assign(:selection_counts, zero_counts())
     |> assign(:reload_scheduled, false)
     |> assign_options()}
  end

  defp assign_options(socket) do
    scope = socket.assigns.current_scope

    batch_options =
      scope
      |> Events.list_batches_with_events()
      |> Enum.map(fn batch -> {"#{batch.event.name} — #{batch.name}", batch.id} end)

    socket
    |> assign(:event_options, Enum.map(Events.list_events(scope), &{&1.name, &1.id}))
    |> assign(:batch_options, batch_options)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load(socket, params, clear_selection?: true)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, push_patch(socket, to: list_path(params))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    participant = Events.get_participant!(socket.assigns.current_scope, id)
    {:ok, _participant} = Events.delete_participant(socket.assigns.current_scope, participant)

    {:noreply, load(socket, socket.assigns.filters)}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = toggle_id(socket.assigns.selected, id)

    {:noreply,
     socket
     |> assign(:selected, selected)
     |> assign_selection_state()}
  end

  def handle_event("toggle_page", _params, socket) do
    selected =
      if socket.assigns.page_all_selected? do
        Enum.reduce(socket.assigns.page_ids, socket.assigns.selected, &MapSet.delete(&2, &1))
      else
        Enum.reduce(socket.assigns.page_ids, socket.assigns.selected, &MapSet.put(&2, &1))
      end

    {:noreply, load(socket, socket.assigns.filters, assign_selected: selected)}
  end

  def handle_event("select_all", _params, socket),
    do: {:noreply, select_by(socket, :all)}

  def handle_event("select_not_generated", _params, socket),
    do: {:noreply, select_by(socket, :not_generated)}

  def handle_event("select_not_sent", _params, socket),
    do: {:noreply, select_by(socket, :not_sent)}

  def handle_event("select_error", _params, socket),
    do: {:noreply, select_by(socket, :error)}

  def handle_event("select_no_email", _params, socket),
    do: {:noreply, select_by(socket, :no_email)}

  def handle_event("clear_selection", _params, socket) do
    {:noreply, socket |> assign(:selected, MapSet.new()) |> assign_selection_state()}
  end

  def handle_event("bulk_generate", _params, socket) do
    ids = MapSet.to_list(socket.assigns.selected)

    if ids == [] do
      {:noreply, socket}
    else
      summary = Certificates.prepare_for_participants(socket.assigns.current_scope, ids)

      {:noreply,
       socket
       |> put_flash(:info, generate_message(summary))
       |> assign(:selected, MapSet.new())
       |> load(socket.assigns.filters)}
    end
  end

  def handle_event("bulk_send", _params, socket) do
    ids = MapSet.to_list(socket.assigns.selected)

    if ids == [] do
      {:noreply, socket}
    else
      summary = Certificates.send_emails(socket.assigns.current_scope, ids)

      {:noreply,
       socket
       |> put_flash(:info, send_message(summary))
       |> assign(:selected, MapSet.new())
       |> load(socket.assigns.filters)}
    end
  end

  @impl true
  def handle_info({type, %Certfy.Events.Participant{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, load(socket, socket.assigns.filters)}
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
     |> load(socket.assigns.filters)}
  end

  defp select_by(socket, selection) do
    ids =
      Certificates.participant_ids(
        socket.assigns.current_scope,
        socket.assigns.filters,
        selection
      )

    load(socket, socket.assigns.filters, assign_selected: MapSet.new(ids))
  end

  defp load(socket, params, opts \\ []) do
    context_batch = fetch_batch(socket, params["batch_id"])

    context_event =
      if context_batch, do: context_batch.event, else: fetch_event(socket, params["event_id"])

    params =
      cond do
        context_batch ->
          params
          |> Map.put("event_id", to_string(context_event.id))
          |> Map.put("batch_id", to_string(context_batch.id))

        context_event ->
          Map.put(params, "event_id", to_string(context_event.id))

        true ->
          params
      end

    result = Events.list_participants_page_all(socket.assigns.current_scope, params)

    filters = %{
      "q" => params["q"] || "",
      "event_id" => params["event_id"] || "",
      "batch_id" => params["batch_id"] || "",
      "certificate" => params["certificate"] || "",
      "page" => result.page
    }

    selected =
      cond do
        Keyword.has_key?(opts, :assign_selected) ->
          Keyword.fetch!(opts, :assign_selected)

        Keyword.get(opts, :clear_selection?, false) and
            filter_changed?(socket.assigns[:filters], filters) ->
          MapSet.new()

        true ->
          socket.assigns[:selected] || MapSet.new()
      end

    page_ids = Enum.map(result.items, & &1.id)

    socket
    |> assign(:filters, filters)
    |> assign(
      :filter_form,
      to_form(Map.take(filters, ["q", "event_id", "batch_id", "certificate"]))
    )
    |> assign(:page_info, result)
    |> assign(:empty?, result.items == [])
    |> assign(:has_filters?, has_filters?(filters, context_batch, context_event))
    |> assign(:context_batch, context_batch)
    |> assign(:context_event, context_event)
    |> assign_context_counts(context_event)
    |> assign(:selected, selected)
    |> assign(:page_ids, page_ids)
    |> assign(
      :page_all_selected?,
      page_ids != [] and Enum.all?(page_ids, &MapSet.member?(selected, &1))
    )
    |> assign(:selection_counts, selection_counts(socket, filters))
    |> assign_selection_state()
    |> stream(:participants, result.items, reset: true)
  end

  defp assign_context_counts(socket, nil) do
    assign(socket, context_batch_count: nil, context_participant_count: nil)
  end

  defp assign_context_counts(socket, event) do
    scope = socket.assigns.current_scope

    assign(socket,
      context_batch_count: Events.count_batches(scope, event),
      context_participant_count: Events.count_participants_for_event(scope, event)
    )
  end

  defp assign_selection_state(socket) do
    selected = socket.assigns.selected
    page_ids = socket.assigns.page_ids

    summary =
      if MapSet.size(selected) == 0 do
        zero_summary()
      else
        Certificates.selection_summary(
          socket.assigns.current_scope,
          MapSet.to_list(selected)
        )
      end

    assign(socket,
      selected_summary: summary,
      page_all_selected?: page_ids != [] and Enum.all?(page_ids, &MapSet.member?(selected, &1))
    )
  end

  defp selection_counts(socket, filters) do
    Certificates.selection_counts(
      socket.assigns.current_scope,
      Map.take(filters, ["q", "event_id", "batch_id"])
    )
  end

  defp filter_changed?(nil, _new), do: true

  defp filter_changed?(old, new) do
    Map.take(old, ["q", "event_id", "batch_id", "certificate"]) !=
      Map.take(new, ["q", "event_id", "batch_id", "certificate"])
  end

  defp has_filters?(filters, context_batch, context_event) do
    filters["q"] != "" or filters["certificate"] != "" or
      (is_nil(context_batch) and filters["batch_id"] != "") or
      (is_nil(context_event) and filters["event_id"] != "")
  end

  defp fetch_batch(_socket, id) when id in [nil, ""], do: nil

  defp fetch_batch(socket, id) do
    Events.get_batch_with_event!(socket.assigns.current_scope, id)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp fetch_event(_socket, id) when id in [nil, ""], do: nil

  defp fetch_event(socket, id) do
    Events.get_event!(socket.assigns.current_scope, id)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp context_title(%{name: name}, _event), do: "Participantes do lote #{name}"
  defp context_title(nil, %{name: name}), do: "Participantes do evento #{name}"
  defp context_title(nil, nil), do: "Participantes"

  defp context_subtitle(%{name: _name}, %{name: event_name}),
    do: "Lote do evento #{event_name}."

  defp context_subtitle(nil, %{name: name}),
    do: "Todos os participantes dos lotes de #{name}."

  defp context_subtitle(nil, nil), do: "Todos os participantes dos seus lotes."

  defp new_participant_path(%{id: id}), do: ~p"/participants/new?batch_id=#{id}"
  defp new_participant_path(nil), do: ~p"/participants/new"

  defp import_path(%{id: id}), do: ~p"/participants/import?batch_id=#{id}"
  defp import_path(nil), do: ~p"/participants/import"

  defp batches_path(%{id: id}), do: ~p"/batches?event_id=#{id}"
  defp batches_path(nil), do: ~p"/batches"

  defp clear_filters_path(%{id: id}, _event), do: ~p"/participants?batch_id=#{id}"
  defp clear_filters_path(nil, %{id: id}), do: ~p"/participants?event_id=#{id}"
  defp clear_filters_path(nil, nil), do: ~p"/participants"

  defp toggle_id(selected, id) do
    if MapSet.member?(selected, id),
      do: MapSet.delete(selected, id),
      else: MapSet.put(selected, id)
  end

  defp zero_summary, do: %{total: 0, regenerate: 0, sent: 0, no_email: 0}

  defp zero_counts, do: %{all: 0, not_generated: 0, not_sent: 0, error: 0, no_email: 0}

  defp certificate_label(nil), do: "Não gerado"
  defp certificate_label(%{status: :pending}), do: "Gerando"
  defp certificate_label(%{status: :processing}), do: "Gerando"
  defp certificate_label(%{status: :failed}), do: "Erro"
  defp certificate_label(%{status: :ready, emailed_at: nil}), do: "Gerado"
  defp certificate_label(%{status: :ready}), do: "Enviado"

  defp certificate_badge_class(nil), do: "badge-ghost"
  defp certificate_badge_class(%{status: :pending}), do: "badge-warning"
  defp certificate_badge_class(%{status: :processing}), do: "badge-warning"
  defp certificate_badge_class(%{status: :failed}), do: "badge-error"
  defp certificate_badge_class(%{status: :ready, emailed_at: nil}), do: "badge-info"
  defp certificate_badge_class(%{status: :ready}), do: "badge-success"

  defp generate_confirm(%{regenerate: 0}), do: nil

  defp generate_confirm(%{regenerate: count}),
    do: "#{count} certificado(s) serão regerados e marcados como não enviados. Continuar?"

  defp send_confirm(%{sent: 0}), do: nil

  defp send_confirm(%{sent: count}),
    do: "#{count} certificado(s) já enviados serão reenviados. Continuar?"

  defp generate_message(summary) do
    parts = ["#{summary.queued} certificado(s) enfileirado(s)."]

    parts =
      if summary.no_template > 0,
        do: parts ++ ["#{summary.no_template} ignorado(s) por evento sem template."],
        else: parts

    parts =
      if summary.invalid_template > 0,
        do:
          parts ++
            ["#{summary.invalid_template} ignorado(s) por template com tags malformadas."],
        else: parts

    if summary.in_progress > 0,
      do: Enum.join(parts ++ ["#{summary.in_progress} já estava(m) em andamento."], " "),
      else: Enum.join(parts, " ")
  end

  defp send_message(summary) do
    parts = ["#{summary.queued} e-mail(s) enfileirado(s)."]

    parts =
      if summary.no_email > 0, do: parts ++ ["#{summary.no_email} sem e-mail."], else: parts

    parts =
      if summary.not_ready > 0,
        do: parts ++ ["#{summary.not_ready} sem certificado pronto."],
        else: parts

    parts =
      if summary.missing > 0,
        do: parts ++ ["#{summary.missing} sem certificado."],
        else: parts

    Enum.join(parts, " ")
  end

  defp list_path(params) do
    query =
      params
      |> Map.take(["q", "event_id", "batch_id", "certificate"])
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    if query == %{},
      do: ~p"/participants",
      else: ~p"/participants" <> "?#{URI.encode_query(query)}"
  end

  defp page_path(filters, page) do
    query =
      filters
      |> Map.take(["q", "event_id", "batch_id", "certificate"])
      |> Map.put("page", page)
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    ~p"/participants" <> "?#{URI.encode_query(query)}"
  end

  defp count_label(1), do: "1 participante"
  defp count_label(total), do: "#{total} participantes"
end
