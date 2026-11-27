defmodule CertfyWeb.EventLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Events.Event

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.header>
        Eventos
        <:subtitle>Gerencie os eventos e seus lotes de certificados.</:subtitle>

        <:actions>
          <.button variant="primary" phx-click="open_event_modal">
            <.icon name="hero-plus" /> Novo evento
          </.button>
        </:actions>
      </.header>

      <.form for={@filter_form} id="event-filters" phx-change="filter" class="mb-4">
        <div class="grid gap-3 md:grid-cols-[minmax(0,1fr)_13rem_13rem] md:items-end">
          <label class="block">
            <span class="mb-1 block text-sm font-medium">Buscar</span>
            <span class="input input-bordered flex w-full items-center gap-2">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-60" />
              <input
                type="search"
                name="q"
                value={@filters["q"]}
                placeholder="Nome do evento"
                class="grow"
                phx-debounce="300"
              />
            </span>
          </label>

          <label class="block">
            <span class="mb-1 block text-sm font-medium">Modelo</span>
            <select name="template" class="select select-bordered w-full">
              <option value="all" selected={@filters["template"] == "all"}>Todos</option>

              <option value="yes" selected={@filters["template"] == "yes"}>Com modelo</option>

              <option value="no" selected={@filters["template"] == "no"}>Sem modelo</option>
            </select>
          </label>

          <label class="block">
            <span class="mb-1 block text-sm font-medium">Ordenar por</span>
            <select name="sort" class="select select-bordered w-full">
              <option value="updated" selected={@filters["sort"] == "updated"}>
                Mais recentes
              </option>

              <option value="name" selected={@filters["sort"] == "name"}>Nome (A–Z)</option>
            </select>
          </label>
        </div>
      </.form>

      <div :if={@empty?}>
        <.empty_state
          title={if @has_filters?, do: "Nenhum evento encontrado", else: "Nenhum evento ainda"}
          description={
            if @has_filters?,
              do: "Ajuste a busca ou os filtros para encontrar o que procura.",
              else: "Crie o primeiro evento para começar a organizar lotes e participantes."
          }
        >
          <:action>
            <.link
              :if={@has_filters?}
              patch={~p"/events"}
              class="btn btn-ghost btn-sm"
            >
              Limpar filtros
            </.link>

            <.button :if={!@has_filters?} variant="primary" phx-click="open_event_modal">
              <.icon name="hero-plus" /> Novo evento
            </.button>
          </:action>
        </.empty_state>
      </div>

      <div :if={!@empty?} class="overflow-hidden rounded-box border border-base-300 bg-base-100">
        <div class="hidden grid-cols-[minmax(0,1fr)_8rem_8rem_13rem] gap-4 border-b border-base-300 px-4 py-3 text-sm font-medium text-base-content/70 md:grid">
          <span>Nome</span> <span>Modelo</span> <span>Dados adicionais</span>
          <span class="text-right">Ações</span>
        </div>

        <div id="events" phx-update="stream">
          <div
            :for={{id, event} <- @streams.events}
            id={id}
            class="relative grid grid-cols-1 gap-2 border-b border-base-300 px-4 py-4 last:border-0 hover:bg-base-200/60 md:grid-cols-[minmax(0,1fr)_8rem_8rem_13rem] md:items-center md:gap-4"
          >
            <.link
              navigate={~p"/events/#{event}"}
              class="absolute inset-0 z-0 rounded-box focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
              aria-label={"Abrir #{event.name}"}
            ></.link>
            <div class="min-w-0">
              <p class="truncate text-base font-medium">{event.name}</p>
            </div>

            <div>
              <span class={template_badge(event)}>
                {if event.template_path, do: "Sim", else: "Não"}
              </span>
            </div>

            <div class="text-sm text-base-content/70 tabular-nums">
              {map_size(event.extra_data || %{})}
            </div>

            <div class="relative z-10 flex flex-wrap justify-end gap-2">
              <.link navigate={~p"/events/#{event}/edit"} class="btn btn-soft">
                Editar
              </.link>

              <button
                type="button"
                class="btn btn-soft btn-error"
                phx-click={JS.push("delete", value: %{id: event.id})}
                data-confirm="Tem certeza que deseja excluir este evento?"
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
            <.link patch={page_path(@filters, @page_info.page - 1)} class="btn btn-sm join-item">
              Anterior
            </.link>
          <% else %>
            <button type="button" class="btn btn-sm join-item btn-disabled" disabled>
              Anterior
            </button>
          <% end %>

          <%= if @page_info.page < @page_info.pages do %>
            <.link patch={page_path(@filters, @page_info.page + 1)} class="btn btn-sm join-item">
              Próxima
            </.link>
          <% else %>
            <button type="button" class="btn btn-sm join-item btn-disabled" disabled>
              Próxima
            </button>
          <% end %>
        </div>
      </div>

      <.modal
        :if={@modal == :new_event}
        id="event-modal"
        title="Novo evento"
        description="Depois de criar, você pode enviar o modelo e adicionar dados adicionais."
      >
        <.form
          for={@event_form}
          id="modal-event-form"
          phx-change="validate_event"
          phx-submit="create_event"
          class="space-y-3"
        >
          <.input field={@event_form[:name]} type="text" label="Nome" required />

          <div class="flex justify-end gap-2">
            <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancelar</button>
            <.button variant="primary" phx-disable-with="Criando...">Criar evento</.button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Events.subscribe_events(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Eventos")
     |> assign(:modal, nil)
     |> assign(:modal_from_url, false)
     |> assign(:event_form, to_form(%{}))
     |> assign(:filters, %{"q" => "", "template" => "all", "sort" => "updated", "page" => 1})
     |> assign(:filter_form, to_form(%{"q" => "", "template" => "all", "sort" => "updated"}))
     |> assign(:page_info, %{items: [], total: 0, page: 1, pages: 1})
     |> assign(:empty?, true)
     |> assign(:has_filters?, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      if params["novo"] do
        socket
        |> assign(:modal, :new_event)
        |> assign(:modal_from_url, true)
        |> assign(:event_form, to_form(event_changeset(socket, %{})))
      else
        socket
      end

    {:noreply, load(socket, params)}
  end

  @impl true
  def handle_event("open_event_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal, :new_event)
     |> assign(:modal_from_url, false)
     |> assign(:event_form, to_form(event_changeset(socket, %{})))}
  end

  def handle_event("close_modal", _params, socket) do
    socket = assign(socket, :modal, nil)

    if socket.assigns.modal_from_url do
      {:noreply, push_patch(socket, to: list_path(socket.assigns.filters))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_event", %{"event" => params}, socket) do
    form =
      socket
      |> event_changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :event_form, form)}
  end

  def handle_event("create_event", %{"event" => params}, socket) do
    scope = socket.assigns.current_scope

    case Events.create_event(scope, params) do
      {:ok, event} ->
        {:noreply, push_navigate(socket, to: ~p"/events/#{event}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :event_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("filter", params, socket) do
    {:noreply, push_patch(socket, to: list_path(params))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(socket.assigns.current_scope, id)
    {:ok, _event} = Events.delete_event(socket.assigns.current_scope, event)

    {:noreply, load(socket, socket.assigns.filters)}
  end

  @impl true
  def handle_info({type, %Certfy.Events.Event{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, load(socket, socket.assigns.filters)}
  end

  defp load(socket, params) do
    result = Events.list_events_page(socket.assigns.current_scope, params)

    filters = %{
      "q" => params["q"] || "",
      "template" => params["template"] || "all",
      "sort" => params["sort"] || "updated",
      "page" => result.page
    }

    socket
    |> assign(:filters, filters)
    |> assign(:filter_form, to_form(Map.take(filters, ["q", "template", "sort"])))
    |> assign(:page_info, result)
    |> assign(:empty?, result.items == [])
    |> assign(:has_filters?, filters["q"] != "" or filters["template"] != "all")
    |> stream(:events, result.items, reset: true)
  end

  defp list_path(params) do
    query =
      params
      |> Map.take(["q", "template", "sort"])
      |> Enum.reject(fn {_key, value} -> value in [nil, "", "all"] end)
      |> Map.new()

    if query == %{}, do: ~p"/events", else: ~p"/events" <> "?#{URI.encode_query(query)}"
  end

  defp page_path(filters, page) do
    query =
      filters
      |> Map.take(["q", "template", "sort"])
      |> Map.put("page", page)
      |> Enum.reject(fn {_key, value} -> value in [nil, "", "all"] end)
      |> Map.new()

    ~p"/events" <> "?#{URI.encode_query(query)}"
  end

  defp count_label(1), do: "1 evento"
  defp count_label(total), do: "#{total} eventos"

  defp event_changeset(socket, params) do
    scope = socket.assigns.current_scope

    %Event{user_id: scope.user.id}
    |> Event.changeset(params, scope)
  end

  defp template_badge(%{template_path: nil}), do: "badge badge-ghost badge-sm"
  defp template_badge(_event), do: "badge badge-success badge-sm"
end
