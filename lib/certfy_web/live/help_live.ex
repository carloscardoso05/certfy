defmodule CertfyWeb.HelpLive do
  use CertfyWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:help}>
      <.header>
        Como funciona
        <:subtitle>O caminho completo, do evento ao certificado enviado.</:subtitle>

        <:actions>
          <.button variant="primary" navigate={~p"/events/new"}>
            <.icon name="hero-plus" /> Novo evento
          </.button>
        </:actions>
      </.header>

      <ol class="grid gap-4 md:grid-cols-2">
        <.step
          number="1"
          title="Crie o evento"
          description="O evento agrupa os lotes e define o modelo usado nos certificados."
          icon="hero-calendar-days"
        >
          <:action>
            <.link navigate={~p"/events"} class="font-medium text-primary hover:underline">
              Ver eventos
            </.link>
          </:action>
        </.step>

        <.step
          number="2"
          title="Crie os lotes"
          description="Um lote é uma turma, dia ou categoria dentro do evento. Cada lote gera seus próprios certificados."
          icon="hero-rectangle-stack"
        >
          <:action>
            <.link navigate={~p"/batches"} class="font-medium text-primary hover:underline">
              Ver lotes
            </.link>
          </:action>
        </.step>

        <.step
          number="3"
          title="Cadastre ou importe participantes"
          description="Cada participante pertence a um lote. Você pode cadastrar um por um ou importar uma planilha CSV ou XLSX."
          icon="hero-users"
        >
          <:action>
            <.link navigate={~p"/participants"} class="font-medium text-primary hover:underline">
              Ver participantes
            </.link>
          </:action>
        </.step>

        <.step
          number="4"
          title="Gere e envie os certificados"
          description="Envie o modelo .pptx no evento, confira a pré-visualização e gere os PDFs por lote."
          icon="hero-document-text"
        >
          <:action>
            <.link navigate={~p"/events"} class="font-medium text-primary hover:underline">
              Escolher um evento
            </.link>
          </:action>
        </.step>
      </ol>

      <div class="mt-6 grid gap-4 md:grid-cols-2">
        <.sheet>
          <.section title="O que é um lote?">
            <p class="text-sm text-base-content/70">
              É uma divisão dentro do evento. Pode representar uma turma, um dia, um turno ou
              qualquer categoria que faça sentido para você. Os participantes e os certificados
              ficam organizados por lote.
            </p>
          </.section>
        </.sheet>

        <.sheet>
          <.section title="O que é o modelo do certificado?">
            <p class="text-sm text-base-content/70">
              É um arquivo .pptx com espaços marcados por tags, como <code class="rounded bg-base-200 px-1 py-0.5">{@sample_tag}</code>. O {Certfy.Branding.name()} preenche esses espaços com os dados do evento, do lote e do participante.
            </p>

            <p class="mt-3 text-sm text-base-content/70">
              O modelo fica no evento, então todos os lotes daquele evento usam o mesmo arquivo.
            </p>
          </.section>
        </.sheet>
      </div>

      <div class="mt-6 flex flex-wrap items-center gap-2 rounded-box border border-primary/30 bg-primary/5 p-5">
        <p class="flex-1 text-sm">
          Quer testar o fluxo completo? Comece criando um evento e siga as abas de cada etapa.
        </p>

        <.button variant="primary" navigate={~p"/events/new"}>
          <.icon name="hero-plus" /> Criar evento
        </.button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Como funciona")
     |> assign(:sample_tag, "{{participante.nome}}")}
  end

  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  slot :action

  defp step(assigns) do
    ~H"""
    <li class="rounded-box border border-base-300 bg-base-100 p-5">
      <div class="flex items-start gap-3">
        <span class="flex size-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
          <.icon name={@icon} class="size-5" />
        </span>

        <div class="min-w-0">
          <p class="text-xs font-medium text-base-content/50">Passo {@number}</p>
          <h2 class="mt-1 font-display text-lg font-semibold">{@title}</h2>
          <p class="mt-1 text-sm text-base-content/70">{@description}</p>

          <div :if={@action != []} class="mt-2 text-sm">
            {render_slot(@action)}
          </div>
        </div>
      </div>
    </li>
    """
  end
end
