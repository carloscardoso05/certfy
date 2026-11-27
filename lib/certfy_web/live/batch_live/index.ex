defmodule CertfyWeb.BatchLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.breadcrumb
        :if={@context_event}
        items={[
          %{label: "Eventos", navigate: ~p"/events"},
          %{label: @context_event.name, navigate: ~p"/events/#{@context_event}"},
          %{label: "Lotes"}
        ]}
      />

      <.header>
        {if @context_event, do: "Lotes de #{@context_event.name}", else: "Todos os lotes"}
        <:subtitle>
          {if @context_event,
            do: "Um lote é uma turma, dia ou categoria dentro do evento.",
            else: "Lotes de todos os seus eventos. Use a busca para encontrar um específico."}
        </:subtitle>

        <:actions>
          <.button
            variant="primary"
            navigate={
              if @context_event,
                do: ~p"/batches/new?event_id=#{@context_event.id}",
                else: ~p"/batches/new"
            }
          >
            <.icon name="hero-plus" /> Novo lote
          </.button>
        </:actions>
      </.header>

      <.event_tabs
        :if={@context_event}
        event={@context_event}
        active={:batches}
        batch_count={@context_batch_count}
        participant_count={@context_participant_count}
      />

      <.form for={@filter_form} id="batch-filters" phx-change="filter" class="mb-4">
        <input
          :if={@context_event}
          type="hidden"
          name="event_id"
          value={@context_event.id}
        />

        <div class={[
          "grid gap-3 md:items-end",
          if(@context_event,
            do: "md:grid-cols-1",
            else: "md:grid-cols-[minmax(0,1fr)_16rem]"
          )
        ]}>
          <label class="block">
            <span class="mb-1 block text-sm font-medium">Buscar</span>
            <span class="input input-bordered flex w-full items-center gap-2">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-60" />
              <input
                type="search"
                name="q"
                value={@filters["q"]}
                placeholder="Nome do lote"
                class="grow"
                phx-debounce="300"
              />
            </span>
          </label>

          <.searchable_select
            :if={is_nil(@context_event)}
            id="batch-filter-event"
            name="event_id"
            label="Evento"
            label_class="mb-1 block text-sm font-medium"
            placeholder="Todos os eventos"
            options={@event_options}
            selected={@filters["event_id"]}
            class="w-full"
          />
        </div>
      </.form>

      <div :if={@empty?}>
        <.empty_state
          title={empty_title(@has_filters?, @context_event)}
          description={empty_description(@has_filters?, @context_event)}
        >
          <:action>
            <.link
              :if={@has_filters?}
              patch={
                if @context_event,
                  do: ~p"/batches?event_id=#{@context_event.id}",
                  else: ~p"/batches"
              }
              class="btn btn-ghost btn-sm"
            >
              Limpar filtros
            </.link>

            <.button
              :if={!@has_filters?}
              variant="primary"
              navigate={
                if @context_event,
                  do: ~p"/batches/new?event_id=#{@context_event.id}",
                  else: ~p"/batches/new"
              }
            >
              <.icon name="hero-plus" /> Criar lote
            </.button>
          </:action>
        </.empty_state>
      </div>

      <div :if={!@empty?} class="overflow-hidden rounded-box border border-base-300 bg-base-100">
        <div class={[
          "hidden gap-4 border-b border-base-300 px-4 py-3 text-sm font-medium text-base-content/70 md:grid",
          if(@context_event,
            do: "grid-cols-[minmax(0,1fr)_7rem_13rem]",
            else: "grid-cols-[minmax(0,1fr)_minmax(0,1fr)_7rem_13rem]"
          )
        ]}>
          <span>Lote</span>
          <span :if={is_nil(@context_event)}>Evento</span>
          <span>Participantes</span>
          <span class="text-right">Ações</span>
        </div>

        <div id="batches" phx-update="stream">
          <div
            :for={{id, batch} <- @streams.batches}
            id={id}
            class={[
              "relative grid grid-cols-1 gap-2 border-b border-base-300 px-4 py-4 last:border-0 hover:bg-base-200/60 md:items-center md:gap-4",
              if(@context_event,
                do: "md:grid-cols-[minmax(0,1fr)_7rem_13rem]",
                else: "md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_7rem_13rem]"
              )
            ]}
          >
            <.link
              navigate={~p"/batches/#{batch}"}
              class="absolute inset-0 z-0 rounded-box focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
              aria-label={"Abrir #{batch.name}"}
            ></.link>

            <div class="min-w-0">
              <p class="truncate text-base font-medium">{batch.name}</p>

              <p
                :if={is_nil(@context_event)}
                class="truncate text-sm text-base-content/60 md:hidden"
              >
                {batch.event.name}
              </p>
            </div>

            <div
              :if={is_nil(@context_event)}
              class="hidden min-w-0 text-sm text-base-content/70 md:block"
            >
              <span class="truncate">{batch.event.name}</span>
            </div>

            <div class="text-sm text-base-content/70 tabular-nums">
              {batch.participants_count}
            </div>

            <div class="relative z-10 flex flex-wrap justify-end gap-2">
              <.link navigate={~p"/batches/#{batch}/edit"} class="btn btn-soft">
                Editar
              </.link>

              <button
                type="button"
                class="btn btn-soft btn-error"
                phx-click={JS.push("delete", value: %{id: batch.id})}
                data-confirm="Tem certeza que deseja excluir este lote?"
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
      Events.subscribe_batches(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Lotes")
     |> assign(:filters, %{"q" => "", "event_id" => "", "page" => 1})
     |> assign(:filter_form, to_form(%{"q" => "", "event_id" => ""}))
     |> assign(:page_info, %{items: [], total: 0, page: 1, pages: 1})
     |> assign(:empty?, true)
     |> assign(:has_filters?, false)
     |> assign(:context_event, nil)
     |> assign(:context_batch_count, nil)
     |> assign(:context_participant_count, nil)
     |> assign(
       :event_options,
       Enum.map(Events.list_events(socket.assigns.current_scope), &{&1.name, &1.id})
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load(socket, params)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply, push_patch(socket, to: list_path(params))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    batch = Events.get_batch!(socket.assigns.current_scope, id)
    {:ok, _batch} = Events.delete_batch(socket.assigns.current_scope, batch)

    {:noreply, load(socket, socket.assigns.filters)}
  end

  @impl true
  def handle_info({type, %Certfy.Events.Batch{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, load(socket, socket.assigns.filters)}
  end

  defp load(socket, params) do
    result = Events.list_batches_page(socket.assigns.current_scope, params)
    context_event = fetch_event(socket, params["event_id"])

    filters = %{
      "q" => params["q"] || "",
      "event_id" => params["event_id"] || "",
      "page" => result.page
    }

    socket
    |> assign(:filters, filters)
    |> assign(:filter_form, to_form(Map.take(filters, ["q", "event_id"])))
    |> assign(:page_info, result)
    |> assign(:empty?, result.items == [])
    |> assign(
      :has_filters?,
      filters["q"] != "" or (is_nil(context_event) and filters["event_id"] != "")
    )
    |> assign(:context_event, context_event)
    |> assign_context_counts(context_event)
    |> stream(:batches, result.items, reset: true)
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

  defp fetch_event(_socket, id) when id in [nil, ""], do: nil

  defp fetch_event(socket, id) do
    Events.get_event!(socket.assigns.current_scope, id)
  rescue
    Ecto.NoResultsError -> nil
  end

  defp empty_title(true, _event), do: "Nenhum lote encontrado"
  defp empty_title(false, %{}), do: "Nenhum lote neste evento"
  defp empty_title(false, nil), do: "Nenhum lote ainda"

  defp empty_description(true, _event), do: "Ajuste a busca para encontrar o que procura."
  defp empty_description(false, %{}), do: "Crie o primeiro lote deste evento."

  defp empty_description(false, nil),
    do: "Abra um evento para criar o primeiro lote."

  defp list_path(params) do
    query =
      params
      |> Map.take(["q", "event_id"])
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    if query == %{}, do: ~p"/batches", else: ~p"/batches" <> "?#{URI.encode_query(query)}"
  end

  defp page_path(filters, page) do
    query =
      filters
      |> Map.take(["q", "event_id"])
      |> Map.put("page", page)
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    ~p"/batches" <> "?#{URI.encode_query(query)}"
  end

  defp count_label(1), do: "1 lote"
  defp count_label(total), do: "#{total} lotes"
end
