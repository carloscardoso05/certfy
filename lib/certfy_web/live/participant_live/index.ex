defmodule CertfyWeb.ParticipantLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:participants}>
      <.header>
        Participantes
        <:subtitle>Todos os participantes dos seus lotes.</:subtitle>

        <:actions>
          <.button variant="primary" navigate={~p"/participants/new"}>
            <.icon name="hero-plus" /> Novo participante
          </.button>
        </:actions>
      </.header>

      <.form for={@filter_form} id="participant-filters" phx-change="filter" class="mb-4">
        <div class="grid gap-3 md:grid-cols-[minmax(0,1fr)_15rem_16rem] md:items-end">
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
            id="participant-filter-batch"
            name="batch_id"
            label="Lote"
            label_class="mb-1 block text-sm font-medium"
            placeholder="Todos"
            options={@batch_options}
            selected={@filters["batch_id"]}
            class="w-full"
          />
        </div>
      </.form>

      <div :if={@empty?}>
        <.empty_state
          title={
            if @has_filters?, do: "Nenhum participante encontrado", else: "Nenhum participante ainda"
          }
          description={
            if @has_filters?,
              do: "Ajuste a busca ou os filtros de evento/lote.",
              else: "Abra um lote para cadastrar o primeiro participante."
          }
        >
          <:action>
            <.link :if={@has_filters?} patch={~p"/participants"} class="btn btn-ghost btn-sm">
              Limpar filtros
            </.link>

            <.button :if={!@has_filters?} variant="primary" navigate={~p"/batches"}>
              <.icon name="hero-rectangle-stack" /> Ver lotes
            </.button>
          </:action>
        </.empty_state>
      </div>

      <div :if={!@empty?} class="overflow-hidden rounded-box border border-base-300 bg-base-100">
        <div class="hidden grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_7rem_13rem] gap-4 border-b border-base-300 px-4 py-3 text-sm font-medium text-base-content/70 md:grid">
          <span>Nome</span> <span>E-mail</span> <span>Evento / lote</span> <span>Dados</span>
          <span class="text-right">Ações</span>
        </div>

        <div id="participants" phx-update="stream">
          <div
            :for={{id, participant} <- @streams.participants}
            id={id}
            class="relative grid grid-cols-1 gap-2 border-b border-base-300 px-4 py-4 last:border-0 hover:bg-base-200/60 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_7rem_13rem] md:items-center md:gap-4"
          >
            <.link
              navigate={~p"/participants/#{participant}"}
              class="absolute inset-0 z-0 rounded-box focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
              aria-label={"Abrir #{participant.name}"}
            ></.link>
            <div class="min-w-0">
              <p class="truncate text-base font-medium">{participant.name}</p>

              <p class="truncate text-sm text-base-content/60 md:hidden">
                {participant.email || "Sem e-mail"}
              </p>
            </div>

            <div class="hidden min-w-0 text-sm text-base-content/70 md:block">
              <span class="truncate">{participant.email || "—"}</span>
            </div>

            <div class="min-w-0 text-sm text-base-content/70">
              <p class="truncate">{participant.batch.event.name}</p>

              <p class="truncate text-xs">{participant.batch.name}</p>
            </div>

            <div class="text-sm text-base-content/70 tabular-nums">
              {map_size(participant.extra_data || %{})}
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
    end

    {:ok,
     socket
     |> assign(:page_title, "Participantes")
     |> assign(:filters, %{"q" => "", "event_id" => "", "batch_id" => "", "page" => 1})
     |> assign(:filter_form, to_form(%{"q" => "", "event_id" => "", "batch_id" => ""}))
     |> assign(:page_info, %{items: [], total: 0, page: 1, pages: 1})
     |> assign(:empty?, true)
     |> assign(:has_filters?, false)
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
    {:noreply, load(socket, params)}
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

  @impl true
  def handle_info({type, %Certfy.Events.Participant{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, load(socket, socket.assigns.filters)}
  end

  defp load(socket, params) do
    result = Events.list_participants_page_all(socket.assigns.current_scope, params)

    filters = %{
      "q" => params["q"] || "",
      "event_id" => params["event_id"] || "",
      "batch_id" => params["batch_id"] || "",
      "page" => result.page
    }

    socket
    |> assign(:filters, filters)
    |> assign(:filter_form, to_form(Map.take(filters, ["q", "event_id", "batch_id"])))
    |> assign(:page_info, result)
    |> assign(:empty?, result.items == [])
    |> assign(
      :has_filters?,
      filters["q"] != "" or filters["event_id"] != "" or filters["batch_id"] != ""
    )
    |> stream(:participants, result.items, reset: true)
  end

  defp list_path(params) do
    query =
      params
      |> Map.take(["q", "event_id", "batch_id"])
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    if query == %{},
      do: ~p"/participants",
      else: ~p"/participants" <> "?#{URI.encode_query(query)}"
  end

  defp page_path(filters, page) do
    query =
      filters
      |> Map.take(["q", "event_id", "batch_id"])
      |> Map.put("page", page)
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    ~p"/participants" <> "?#{URI.encode_query(query)}"
  end

  defp count_label(1), do: "1 participante"
  defp count_label(total), do: "#{total} participantes"
end
