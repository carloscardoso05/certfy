defmodule CertfyWeb.EventLive.Template do
  use CertfyWeb, :live_view

  alias Certfy.{Events, Storage}
  alias Certfy.Certificates.{Pptx, Tags}

  @max_size 20_000_000

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:events}>
      <.breadcrumb items={[
        %{label: "Eventos", navigate: ~p"/events"},
        %{label: @event.name, navigate: ~p"/events/#{@event}"},
        %{label: "Modelo"}
      ]} />

      <.header>
        Modelo do certificado
        <:subtitle>Arquivo .pptx, tags e valores disponíveis para {@event.name}.</:subtitle>

        <:actions>
          <.button navigate={~p"/events/#{@event}"} variant="ghost">
            <.icon name="hero-arrow-left" /> Voltar para o evento
          </.button>

          <.button
            :if={@event.template_path}
            href={~p"/events/#{@event}/template/download"}
            variant="soft"
          >
            <.icon name="hero-arrow-down-tray" /> Baixar .pptx
          </.button>

          <.link
            :if={@event.template_path}
            href={~p"/events/#{@event}/template/preview"}
            target="_blank"
            rel="noopener"
            class="btn btn-soft"
          >
            <.icon name="hero-eye" /> Pré-visualizar
          </.link>

          <.link
            :if={@event.template_path != nil and @malformed == []}
            href={
              if @selected_participant,
                do: ~p"/events/#{@event}/template/preview?participant_id=#{@selected_participant.id}",
                else: ~p"/events/#{@event}/template/preview?sample=1"
            }
            target="_blank"
            rel="noopener"
            class="btn btn-primary"
          >
            <.icon name="hero-user" /> Pré-visualizar com dados
          </.link>
        </:actions>
      </.header>

      <.event_tabs
        event={@event}
        active={:template}
        batch_count={@batch_count}
        participant_count={@participant_count}
      />

      <div class="mb-4 grid gap-3 rounded-box border border-base-300 bg-base-100 p-5 md:grid-cols-3">
        <div class="flex gap-3">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
            1
          </span>
          <div>
            <p class="font-medium">Monte o .pptx</p>
            <p class="mt-1 text-sm text-base-content/65">
              Escreva tags como
              <code class="rounded bg-base-200 px-1 py-0.5" phx-no-curly-interpolation>{{participant.name}}</code>
              nos lugares que serão preenchidos.
            </p>
          </div>
        </div>

        <div class="flex gap-3">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
            2
          </span>
          <div>
            <p class="font-medium">Envie o arquivo</p>
            <p class="mt-1 text-sm text-base-content/65">
              O Certfy confere as tags encontradas e avisa se alguma estiver malformada.
            </p>
          </div>
        </div>

        <div class="flex gap-3">
          <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-semibold text-primary">
            3
          </span>
          <div>
            <p class="font-medium">Pré-visualize e gere</p>
            <p class="mt-1 text-sm text-base-content/65">
              Confira com um participante e gere os certificados no lote.
            </p>
          </div>
        </div>
      </div>

      <div
        :if={@malformed != []}
        class="mb-4 rounded-box border border-error/40 bg-error/10 p-4 text-sm"
        role="alert"
      >
        <p class="font-semibold text-error">Este modelo tem tags malformadas.</p>
        <p class="mt-1 text-base-content/70">
          A geração e a pré-visualização com dados ficam bloqueadas até o arquivo ser corrigido e
          reenviado.
        </p>
        <ul class="mt-2 list-disc pl-5">
          <li :for={item <- @malformed}>
            Slide {item["slide"]}: <code class="break-all">{item["raw"]}</code>
          </li>
        </ul>
      </div>

      <div class="grid gap-4 lg:grid-cols-[22rem_minmax(0,1fr)]">
        <div class="space-y-4">
          <.sheet>
            <.section
              title="Arquivo do modelo"
              description="Envie ou substitua o .pptx deste evento."
            >
              <p :if={@event.template_path} class="mb-3 text-sm text-base-content/70">
                Já existe um modelo enviado. Enviar outro substitui o arquivo atual.
              </p>

              <.form
                for={@upload_form}
                id="template-upload-form"
                phx-submit="save_template"
                phx-change="validate_upload"
              >
                <.live_file_input
                  upload={@uploads.template}
                  class="file-input file-input-bordered w-full"
                />

                <p class="mt-2 text-sm text-base-content/60">
                  Apenas .pptx, até 20 MB.
                </p>

                <p
                  :for={error <- upload_errors(@uploads.template)}
                  class="mt-2 text-sm text-error"
                >
                  {upload_error(error)}
                </p>

                <div :for={entry <- @uploads.template.entries} class="mt-3 space-y-1">
                  <div class="flex items-center justify-between gap-2 text-sm">
                    <span class="truncate">{entry.client_name}</span>
                    <button
                      type="button"
                      class="btn btn-soft btn-error btn-sm"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                    >
                      Remover
                    </button>
                  </div>

                  <progress class="progress progress-primary w-full" value={entry.progress} max="100">
                    {entry.progress}%
                  </progress>

                  <p
                    :for={error <- upload_errors(@uploads.template, entry)}
                    class="text-sm text-error"
                  >
                    {upload_error(error)}
                  </p>
                </div>

                <.button variant="primary" class="mt-3 w-full" phx-disable-with="Enviando...">
                  <.icon name="hero-arrow-up-tray" /> Enviar modelo
                </.button>
              </.form>

              <.button
                :if={@event.template_path}
                phx-click="remove_template"
                data-confirm="Remover o modelo deste evento?"
                variant="danger"
                class="mt-3 w-full"
              >
                <.icon name="hero-trash" /> Remover modelo
              </.button>
            </.section>
          </.sheet>
        </div>

        <div class="space-y-4">
          <.sheet>
            <.section
              title="Como usar as tags"
              description="As tags são espaços reservados que o Certfy preenche na geração."
            >
              <p class="text-sm text-base-content/70">
                Copie a tag e cole no PowerPoint, no lugar onde o valor deve aparecer. Você pode
                usar as tags dentro de caixas de texto, tabelas e formas.
              </p>

              <ul class="mt-4 space-y-2 text-sm">
                <li>
                  <code class="rounded bg-base-200 px-1 py-0.5" phx-no-curly-interpolation>{{event.name}}</code>
                  <span class="text-base-content/65">— nome do evento.</span>
                </li>
                <li>
                  <code class="rounded bg-base-200 px-1 py-0.5" phx-no-curly-interpolation>{{batch.name}}</code>
                  <span class="text-base-content/65">— nome do lote.</span>
                </li>
                <li>
                  <code class="rounded bg-base-200 px-1 py-0.5" phx-no-curly-interpolation>{{participant.name}}</code>
                  <span class="text-base-content/65">— nome do participante.</span>
                </li>
                <li>
                  <code class="rounded bg-base-200 px-1 py-0.5" phx-no-curly-interpolation>{{participant.email}}</code>
                  <span class="text-base-content/65">— e-mail do participante.</span>
                </li>
                <li>
                  <code class="rounded bg-base-200 px-1 py-0.5" phx-no-curly-interpolation>{{qrcode}}</code>
                  <span class="text-base-content/65">— QR code de validação do certificado.</span>
                </li>
              </ul>

              <p class="mt-4 text-sm text-base-content/60">
                Os demais dados do evento, do lote e do participante aparecem na tabela abaixo.
              </p>
            </.section>
          </.sheet>

          <.sheet>
            <.section
              title="Tags no modelo"
              description="Tags encontradas no arquivo atual."
            >
              <p :if={@template_tags == []} class="text-sm text-base-content/60">
                Nenhuma tag encontrada.
              </p>

              <div :if={@template_tags != []} class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>Tag</th><th>Ocorrências</th><th>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={tag <- @template_tags}>
                      <td class="font-mono text-xs break-all">{tag["tag"]}</td>
                      <td>{tag["count"]}</td>
                      <td class={tag_status_class(tag, @values)}>
                        {tag_status(tag, @values, @catalog_tags)}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </.section>
          </.sheet>
        </div>
      </div>

      <.sheet class="mt-4">
        <.section
          title="Tags que você pode usar"
          description="Copie a tag e cole no PowerPoint. Escolha um participante para ver valores reais."
        >
          <.form
            for={@participant_form}
            id="participant-select-form"
            phx-change="select_participant"
          >
            <.searchable_select
              id="template-participant"
              name="participant_id"
              label="Valores de exemplo"
              placeholder="Dados de exemplo"
              options={@participant_options}
              selected={@selected_participant && @selected_participant.id}
              class="w-full"
            />
          </.form>

          <p class="mt-2 text-sm text-base-content/60">
            Sem um participante selecionado, os valores são exemplos.
          </p>

          <div class="mt-4 overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Tag</th>
                  <th>Exemplo</th>
                  <th>Disponibilidade</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={row <- @catalog_rows}>
                  <td>
                    <p class="font-mono text-xs break-all">{row.tag}</p>
                    <p class="mt-0.5 text-xs text-base-content/55">{row.source}</p>
                  </td>
                  <td class="max-w-56 break-words text-sm">{row.value}</td>
                  <td class="whitespace-nowrap text-xs text-base-content/60">
                    {row.availability}
                  </td>
                  <td>
                    <button
                      type="button"
                      class="btn btn-ghost btn-xs"
                      data-copy={row.tag}
                      phx-hook="CopyTag"
                      id={"copy-#{row.id}"}
                      aria-label={"Copiar #{row.tag}"}
                    >
                      <.icon name="hero-clipboard" class="size-4" />
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.section>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    event = Events.get_event!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Modelo do certificado")
     |> assign(:event, event)
     |> assign(:upload_form, to_form(%{}))
     |> assign(:participant_form, to_form(%{}))
     |> assign(:selected_participant, nil)
     |> allow_upload(:template,
       accept: ~w(.pptx),
       max_entries: 1,
       max_file_size: @max_size
     )
     |> load_template_data()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    event = socket.assigns.event

    participant =
      case params["participant_id"] do
        nil ->
          nil

        id ->
          try do
            p = Events.get_participant_with_context!(socket.assigns.current_scope, id)
            if p.batch.event_id == event.id, do: p, else: nil
          rescue
            Ecto.NoResultsError -> nil
          end
      end

    {:noreply,
     socket
     |> assign(:selected_participant, participant)
     |> load_template_data()}
  end

  @impl true
  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :template, ref)}
  end

  def handle_event("select_participant", %{"participant_id" => ""}, socket) do
    {:noreply, push_patch(socket, to: ~p"/events/#{socket.assigns.event}/template")}
  end

  def handle_event("select_participant", %{"participant_id" => id}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/events/#{socket.assigns.event}/template?participant_id=#{id}"
     )}
  end

  def handle_event("save_template", _params, socket) do
    case consume_upload(socket) do
      {:ok, binary, filename} ->
        case Pptx.analyze(binary) do
          {:ok, report} ->
            key = Storage.template_key(filename)
            old_path = socket.assigns.event.template_path

            with {:ok, _} <- put_template(key, binary),
                 {:ok, event} <-
                   Events.update_event_template(
                     socket.assigns.current_scope,
                     socket.assigns.event,
                     %{
                       template_path: key,
                       template_report: report,
                       template_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
                     }
                   ) do
              if old_path do
                Storage.delete_template(old_path)
                Storage.delete_object(old_path <> ".preview.pdf")
              end

              {:noreply,
               socket
               |> assign(:event, event)
               |> put_flash(:info, "Modelo enviado.")
               |> load_template_data()}
            else
              _ ->
                {:noreply, put_flash(socket, :error, "Não foi possível salvar o modelo.")}
            end

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "O arquivo não é um .pptx válido.")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("remove_template", _params, socket) do
    event = socket.assigns.event
    old_path = event.template_path

    with {:ok, event} <-
           Events.update_event_template(socket.assigns.current_scope, event, %{
             template_path: nil,
             template_report: %{},
             template_checked_at: nil
           }) do
      if old_path do
        Storage.delete_template(old_path)
        Storage.delete_object(old_path <> ".preview.pdf")
      end

      {:noreply,
       socket
       |> assign(:event, event)
       |> put_flash(:info, "Modelo removido.")
       |> load_template_data()}
    else
      _ -> {:noreply, put_flash(socket, :error, "Não foi possível remover o modelo.")}
    end
  end

  @impl true
  def handle_info(
        {:updated, %Certfy.Events.Event{id: id} = event},
        %{assigns: %{event: %{id: id}}} = socket
      ) do
    {:noreply, socket |> assign(:event, event) |> load_template_data()}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp consume_upload(socket) do
    case socket.assigns.uploads.template.entries do
      [] ->
        {:error, "Selecione um arquivo .pptx."}

      [_entry] ->
        results =
          consume_uploaded_entries(socket, :template, fn %{path: path}, entry ->
            case File.read(path) do
              {:ok, binary} -> {:ok, {binary, entry.client_name}}
              {:error, _} -> {:error, :read_failed}
            end
          end)

        case results do
          [{binary, filename}] -> {:ok, binary, filename}
          _ -> {:error, "Não foi possível ler o arquivo enviado."}
        end
    end
  end

  defp put_template(key, binary) do
    Storage.put_template(
      key,
      binary,
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    )
  end

  defp load_template_data(socket) do
    scope = socket.assigns.current_scope
    event = socket.assigns.event
    participants = Events.list_participants_for_event(scope, event)
    selected = socket.assigns.selected_participant

    report = event.template_report || %{}
    template_tags = report["tags"] || []
    malformed = report["malformed"] || []

    values =
      if selected do
        Tags.build(selected, selected.batch, event, %{code: "EXEMPLO123"})
      else
        %{
          "event.name" => event.name,
          "batch.name" => "Lote de exemplo",
          "participant.name" => "Maria da Silva",
          "participant.email" => "maria@exemplo.com",
          "certificate.code" => "EXEMPLO123",
          "certificate.issued_at" => Calendar.strftime(Date.utc_today(), "%d/%m/%Y")
        }
      end

    socket
    |> assign(:participants, participants)
    |> assign(:participant_options, Enum.map(participants, &{&1.name, &1.id}))
    |> assign(:template_tags, template_tags)
    |> assign(:malformed, malformed)
    |> assign(:values, values)
    |> assign(:batch_count, Events.count_batches(scope, event))
    |> assign(:participant_count, length(participants))
    |> assign(
      :catalog_rows,
      catalog_rows(scope, event, participants, selected, values)
    )
    |> then(fn socket ->
      assign(socket, :catalog_tags, MapSet.new(socket.assigns.catalog_rows, & &1.tag))
    end)
  end

  defp catalog_rows(scope, event, participants, selected, values) do
    batches = Events.list_batches(scope, event)
    total_batches = length(batches)
    total_participants = length(participants)

    base =
      [
        row("event-name", "Evento", "Nome", "{{event.name}}", values["event.name"], "sempre"),
        row(
          "batch-name",
          "Lote",
          "Nome",
          "{{batch.name}}",
          values["batch.name"],
          "#{total_batches} lote(s)"
        ),
        row(
          "participant-name",
          "Participante",
          "Nome",
          "{{participant.name}}",
          values["participant.name"],
          "#{total_participants} participante(s)"
        ),
        row(
          "participant-email",
          "Participante",
          "E-mail",
          "{{participant.email}}",
          values["participant.email"],
          "#{Enum.count(participants, &(&1.email not in [nil, ""]))} com e-mail"
        ),
        row(
          "certificate-code",
          "Certificado",
          "Código",
          "{{certificate.code}}",
          "EXEMPLO123",
          "gerado na emissão"
        ),
        row(
          "certificate-date",
          "Certificado",
          "Emissão",
          "{{certificate.issued_at}}",
          values["certificate.issued_at"],
          "gerado na emissão"
        )
      ]

    event_rows =
      Enum.map(event.extra_data || %{}, fn {key, value} ->
        normalized = Tags.normalize_key(key)
        row("event-#{normalized}", "Evento", key, "{{event.#{normalized}}}", value, "evento")
      end)

    batch_rows = extra_rows("batch", batches, total_batches, selected && selected.batch, "Lote")

    participant_rows =
      extra_rows("participant", participants, total_participants, selected, "Participante")

    (base ++ event_rows ++ batch_rows ++ participant_rows)
    |> Enum.uniq_by(& &1.tag)
  end

  defp extra_rows(prefix, records, total, selected_record, source) do
    records
    |> Enum.flat_map(fn record ->
      Map.keys(record.extra_data || %{}) |> Enum.map(&{&1, record})
    end)
    |> Enum.group_by(fn {key, _record} -> Tags.normalize_key(key) end)
    |> Enum.map(fn {normalized, entries} ->
      {key, record} = hd(entries)

      selected_value =
        if selected_record do
          (selected_record.extra_data || %{})[key]
        else
          record.extra_data[key]
        end

      example = selected_value

      row(
        "#{prefix}-#{normalized}",
        source,
        key,
        "{{#{prefix}.#{normalized}}}",
        example,
        "#{length(entries)} de #{total} #{String.downcase(source)}(s)"
      )
    end)
  end

  defp row(id, source, key, tag, value, availability) do
    %{
      id: id,
      source: source,
      key: key,
      tag: tag,
      value: if(value in [nil, ""], do: "—", else: to_string(value)),
      availability: availability
    }
  end

  defp tag_status(%{"tag" => "qrcode"}, _values, _catalog), do: "QR"

  defp tag_status(tag, values, catalog) do
    cond do
      Map.has_key?(values, tag["tag"]) and values[tag["tag"]] in [nil, ""] -> "sem valor"
      Map.has_key?(values, tag["tag"]) -> "ok"
      MapSet.member?(catalog, tag["tag"]) -> "sem valor neste registro"
      true -> "desconhecida"
    end
  end

  defp tag_status_class(_tag, _values), do: "text-sm"

  defp upload_error(:too_large), do: "Arquivo maior que 20 MB."
  defp upload_error(:not_accepted), do: "Envie apenas um arquivo .pptx."
  defp upload_error(:too_many_files), do: "Envie apenas um arquivo."
  defp upload_error(error), do: "Falha no upload: #{inspect(error)}"
end
