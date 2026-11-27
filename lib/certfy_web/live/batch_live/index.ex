defmodule CertfyWeb.BatchLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:batches}>
      <.header>
        Lotes
        <:subtitle>Todos os lotes dos seus eventos.</:subtitle>

        <:actions>
          <.button variant="soft" navigate={~p"/participants/import"}>
            <.icon name="hero-table-cells" /> Importar planilha
          </.button>

          <.button variant="primary" navigate={~p"/batches/new"}>
            <.icon name="hero-plus" /> Novo lote
          </.button>
        </:actions>
      </.header>

      <.form for={@filter_form} id="batch-filters" phx-change="filter" class="mb-4">
        <div class="grid gap-3 md:grid-cols-[minmax(0,1fr)_16rem] md:items-end">
          <label class="block">
            <span class="mb-1 block text-sm font-medium">Buscar</span>
            <span class="input input-bordered flex w-full items-center gap-2">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-60" />
              <input
                type="search"
                name="q"
                value={@filters["q"]}
                placeholder="Lote ou evento"
                class="grow"
                phx-debounce="300"
              />
            </span>
          </label>

          <.searchable_select
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
          title={if @has_filters?, do: "Nenhum lote encontrado", else: "Nenhum lote ainda"}
          description={
            if @has_filters?,
              do: "Ajuste a busca ou o filtro de evento.",
              else: "Abra um evento para criar o primeiro lote."
          }
        >
          <:action>
            <.link :if={@has_filters?} patch={~p"/batches"} class="btn btn-ghost btn-sm">
              Limpar filtros
            </.link>

            <.button :if={!@has_filters?} variant="primary" navigate={~p"/events"}>
              <.icon name="hero-calendar-days" /> Ver eventos
            </.button>
          </:action>
        </.empty_state>
      </div>

      <div :if={!@empty?} class="overflow-hidden rounded-box border border-base-300 bg-base-100">
        <div class="hidden grid-cols-[minmax(0,1fr)_minmax(0,1fr)_7rem_13rem] gap-4 border-b border-base-300 px-4 py-3 text-sm font-medium text-base-content/70 md:grid">
          <span>Lote</span> <span>Evento</span> <span>Participantes</span>
          <span class="text-right">Ações</span>
        </div>

        <div id="batches" phx-update="stream">
          <div
            :for={{id, batch} <- @streams.batches}
            id={id}
            class="relative grid grid-cols-1 gap-2 border-b border-base-300 px-4 py-4 last:border-0 hover:bg-base-200/60 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_7rem_13rem] md:items-center md:gap-4"
          >
            <.link
              navigate={~p"/batches/#{batch}"}
              class="absolute inset-0 z-0 rounded-box focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
              aria-label={"Abrir #{batch.name}"}
            ></.link>
            <div class="min-w-0">
              <p class="truncate text-base font-medium">{batch.name}</p>

              <p class="truncate text-sm text-base-content/60 md:hidden">{batch.event.name}</p>
            </div>

            <div class="hidden min-w-0 text-sm text-base-content/70 md:block">
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
    |> assign(:has_filters?, filters["q"] != "" or filters["event_id"] != "")
    |> stream(:batches, result.items, reset: true)
  end

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
