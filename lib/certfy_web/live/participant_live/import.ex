defmodule CertfyWeb.ParticipantLive.Import do
  use CertfyWeb, :live_view

  alias Certfy.Events
  alias Certfy.Imports.{Columns, ParticipantPlan, Spreadsheet}

  @max_size 5_000_000

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:participants}>
      <.breadcrumb
        :if={@batch}
        items={[
          %{label: "Eventos", navigate: ~p"/events"},
          %{label: @batch.event.name, navigate: ~p"/events/#{@batch.event}"},
          %{label: @batch.name, navigate: ~p"/batches/#{@batch}"},
          %{label: "Importar planilha"}
        ]}
      />

      <.breadcrumb
        :if={is_nil(@batch)}
        items={[
          %{label: "Participantes", navigate: ~p"/participants"},
          %{label: "Importar planilha"}
        ]}
      />

      <.header>
        Importar participantes
        <:subtitle>Envie um CSV ou XLSX para o lote selecionado.</:subtitle>

        <:actions>
          <.button
            :if={@batch}
            variant="ghost"
            navigate={~p"/participants?batch_id=#{@batch.id}"}
          >
            <.icon name="hero-arrow-left" /> Voltar para participantes
          </.button>
        </:actions>
      </.header>

      <%= case @step do %>
        <% :upload -> %>
          <div class="mx-auto w-full max-w-2xl">
            <.sheet>
              <.section
                title="Lote de destino"
                description="Escolha onde os participantes serão criados."
              >
                <.form for={@batch_form} id="import-batch-form" phx-change="select_batch">
                  <.searchable_select
                    id="import-batch"
                    name="batch_id"
                    label="Lote"
                    placeholder="Selecione um lote"
                    options={@batch_options}
                    selected={@batch && @batch.id}
                    class="w-full"
                  />
                </.form>

                <p :if={is_nil(@batch)} class="mt-2 text-sm text-base-content/60">
                  Selecione um lote antes de enviar a planilha.
                </p>
              </.section>

              <.section
                title="Planilha"
                description="A primeira linha pode conter os títulos das colunas."
              >
                <.form
                  for={@upload_form}
                  id="import-upload-form"
                  phx-change="validate_upload"
                  phx-submit="analyze"
                >
                  <.live_file_input
                    upload={@uploads.planilha}
                    class="file-input file-input-bordered w-full"
                  />

                  <p class="mt-2 text-sm text-base-content/60">
                    Aceita .csv e .xlsx, até 5 MB. Colunas Nome e E-mail são identificadas
                    automaticamente; as demais viram dados adicionais.
                  </p>

                  <p
                    :for={error <- upload_errors(@uploads.planilha)}
                    class="mt-2 text-sm text-error"
                  >
                    {upload_error(error)}
                  </p>

                  <div :for={entry <- @uploads.planilha.entries} class="mt-3 space-y-1">
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

                    <progress
                      class="progress progress-primary w-full"
                      value={entry.progress}
                      max="100"
                    >
                      {entry.progress}%
                    </progress>

                    <p
                      :for={error <- upload_errors(@uploads.planilha, entry)}
                      class="text-sm text-error"
                    >
                      {upload_error(error)}
                    </p>
                  </div>

                  <.button
                    variant="primary"
                    class="mt-3 w-full"
                    phx-disable-with="Analisando..."
                    disabled={is_nil(@batch)}
                  >
                    <.icon name="hero-table-cells" /> Analisar planilha
                  </.button>
                </.form>
              </.section>
            </.sheet>
          </div>
        <% :preview -> %>
          <div class="space-y-4">
            <div class="flex flex-wrap items-center gap-2 rounded-box border border-base-300 bg-base-100 p-4">
              <p class="text-base font-medium">
                {@plan.total} linha(s) · {@plan.valid |> length()} pronta(s)
              </p>
              <p :if={@plan.invalid > 0} class="text-sm text-error">
                {@plan.invalid} com erro
              </p>
              <p :if={@plan.blank > 0} class="text-sm text-base-content/60">
                {@plan.blank} em branco
              </p>
              <p :if={@plan.emails_cleared > 0} class="text-sm text-base-content/60">
                {@plan.emails_cleared} e-mail(s) inválido(s) removido(s)
              </p>
              <div class="flex-1"></div>
              <button type="button" class="btn btn-soft" phx-click="reset">
                Voltar
              </button>
            </div>

            <div
              :if={@mapping_errors != []}
              class="rounded-box border border-warning/40 bg-warning/10 p-4"
            >
              <p :for={error <- @mapping_errors} class="text-sm text-warning">{error}</p>
            </div>

            <div class="rounded-box border border-base-300 bg-base-100">
              <.section
                title="Cabeçalho"
                description="Indique o que a primeira linha da planilha contém."
              >
                <.form for={@header_form} id="header-form" phx-change="change_header">
                  <select name="header" class="select select-bordered w-full max-w-sm">
                    <option value="true" selected={@analysis.header_row != nil}>
                      Títulos das colunas
                    </option>
                    <option value="false" selected={@analysis.header_row == nil}>
                      Dados de um participante
                    </option>
                  </select>
                </.form>

                <p class="mt-2 text-sm text-base-content/60">
                  Se a primeira linha for título, ela não vira participante. Caso contrário,
                  ela entra como o primeiro registro.
                </p>
              </.section>
            </div>

            <div class="rounded-box border border-base-300 bg-base-100">
              <.section title="Colunas" description="Confira ou ajuste o papel de cada coluna.">
                <.form
                  for={@mapping_form}
                  id="mapping-form"
                  phx-change="update_mapping"
                  phx-debounce="300"
                >
                  <div class="overflow-x-auto">
                    <table class="table table-sm">
                      <thead>
                        <tr>
                          <th>Coluna</th>
                          <th>Exemplos</th>
                          <th>Usar como</th>
                          <th>Chave em dados adicionais</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr :for={column <- @columns}>
                          <td class="font-medium">{column.label}</td>
                          <td class="max-w-64 text-xs text-base-content/60">
                            {Enum.join(column.samples, " · ")}
                          </td>
                          <td>
                            <select
                              name={"mapping[#{column.index}][kind]"}
                              class="select select-bordered select-sm"
                            >
                              <option value="name" selected={column.kind == :name}>Nome</option>
                              <option value="email" selected={column.kind == :email}>E-mail</option>
                              <option value="extra" selected={column.kind == :extra}>
                                Dado adicional
                              </option>
                              <option value="ignore" selected={column.kind == :ignore}>
                                Ignorar
                              </option>
                            </select>
                          </td>
                          <td>
                            <input
                              type="text"
                              name={"mapping[#{column.index}][key]"}
                              value={column.key}
                              class="input input-bordered input-sm w-full"
                              disabled={column.kind != :extra}
                            />
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </.form>
              </.section>
            </div>

            <div class="rounded-box border border-base-300 bg-base-100">
              <.section title="Prévia" description="Primeiras 50 linhas da planilha.">
                <div class="overflow-x-auto">
                  <table class="table table-sm">
                    <thead>
                      <tr>
                        <th>Linha</th><th>Nome</th><th>E-mail</th><th>Status</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr :for={row <- @plan.sample}>
                        <td>{row.row}</td>
                        <td class="break-words">{row.name}</td>
                        <td class="break-words">{row.email}</td>
                        <td class={(row.status == "ok" && "text-success") || "text-error"}>
                          {if row.status == "ok", do: "ok", else: row.message}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </.section>
            </div>

            <div class="flex flex-wrap justify-end gap-2">
              <button type="button" class="btn btn-soft" phx-click="reset">Cancelar</button>

              <button
                type="button"
                class="btn btn-primary"
                phx-click="import"
                disabled={@mapping_errors != [] or @plan.valid == []}
                data-confirm={import_confirm(@plan)}
              >
                <.icon name="hero-arrow-down-tray" /> Importar {length(@plan.valid)} participante(s)
              </button>
            </div>
          </div>
        <% :result -> %>
          <div class="mx-auto w-full max-w-xl">
            <.sheet>
              <.section title="Importação concluída">
                <p class="text-base">
                  <strong>{@result.inserted}</strong>
                  participante(s) importado(s) para o lote <strong>{@batch.name}</strong>.
                </p>
                <p :if={@result.errors > 0} class="mt-2 text-sm text-error">
                  {@result.errors} linha(s) não puderam ser importadas.
                </p>
                <p :if={@result.emails_cleared > 0} class="mt-2 text-sm text-base-content/60">
                  {@result.emails_cleared} e-mail(s) inválido(s) foram removidos.
                </p>

                <div class="mt-4 flex flex-wrap gap-2">
                  <button type="button" class="btn btn-soft" phx-click="reset">
                    Importar outra planilha
                  </button>
                  <.button navigate={~p"/participants?batch_id=#{@batch.id}"} variant="primary">
                    Ver participantes do lote
                  </.button>
                </div>
              </.section>
            </.sheet>
          </div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    batches = Events.list_batches_with_events(socket.assigns.current_scope)
    options = Enum.map(batches, fn batch -> {"#{batch.event.name} — #{batch.name}", batch.id} end)

    {:ok,
     socket
     |> assign(:page_title, "Importar participantes")
     |> assign(:step, :upload)
     |> assign(:batch_options, options)
     |> assign(:batch, nil)
     |> assign(:rows, [])
     |> assign(:batch_form, to_form(%{}))
     |> assign(:upload_form, to_form(%{}))
     |> assign(:mapping_form, to_form(%{}))
     |> assign(:header_form, to_form(%{}))
     |> assign(:columns, [])
     |> assign(:mapping_errors, [])
     |> assign(:plan, %{
       valid: [],
       errors: [],
       sample: [],
       total: 0,
       invalid: 0,
       blank: 0,
       emails_cleared: 0
     })
     |> allow_upload(:planilha,
       accept: ~w(.csv .xlsx),
       max_entries: 1,
       max_file_size: @max_size
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    batch =
      case params["batch_id"] do
        nil ->
          nil

        id ->
          try do
            Events.get_batch_with_event!(socket.assigns.current_scope, id)
          rescue
            Ecto.NoResultsError -> nil
          end
      end

    {:noreply, assign(socket, :batch, batch)}
  end

  @impl true
  def handle_event("select_batch", %{"batch_id" => ""}, socket) do
    {:noreply, push_patch(socket, to: ~p"/participants/import")}
  end

  def handle_event("select_batch", %{"batch_id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/participants/import?batch_id=#{id}")}
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :planilha, ref)}
  end

  def handle_event("analyze", _params, socket) do
    if is_nil(socket.assigns.batch) do
      {:noreply, put_flash(socket, :error, "Selecione um lote antes de importar.")}
    else
      case consume_file(socket) do
        {:ok, binary, filename} ->
          case Spreadsheet.load(binary, filename) do
            {:ok, rows, _meta} ->
              case Columns.detect(rows) do
                {:ok, analysis} ->
                  plan = build_plan(analysis)
                  errors = Columns.validation_errors(analysis.columns)

                  {:noreply,
                   socket
                   |> assign(:step, :preview)
                   |> assign(:rows, rows)
                   |> assign(:analysis, analysis)
                   |> assign(:columns, analysis.columns)
                   |> assign(:mapping_errors, errors)
                   |> assign(:plan, plan)
                   |> assign(:mapping_form, to_form(%{}))
                   |> assign(:header_form, to_form(%{}))}

                {:error, _} ->
                  {:noreply, put_flash(socket, :error, "A planilha está vazia.")}
              end

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, spreadsheet_error(reason))}
          end

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    end
  end

  def handle_event("change_header", %{"header" => value}, socket) do
    case Columns.detect(socket.assigns.rows, header: value == "true") do
      {:ok, analysis} ->
        {:noreply,
         socket
         |> assign(:analysis, analysis)
         |> assign(:columns, analysis.columns)
         |> assign(:mapping_errors, Columns.validation_errors(analysis.columns))
         |> assign(:plan, build_plan(analysis))
         |> assign(:mapping_form, to_form(%{}))}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("update_mapping", %{"mapping" => mapping}, socket) do
    columns =
      Enum.map(socket.assigns.columns, fn column ->
        params = Map.get(mapping, to_string(column.index), %{})
        kind = kind_from_params(params["kind"], column.kind)
        key = if kind == :extra, do: params["key"] || column.key, else: column.key

        %{column | kind: kind, key: key}
      end)

    analysis = %{socket.assigns.analysis | columns: columns}
    errors = Columns.validation_errors(columns)

    {:noreply,
     socket
     |> assign(:columns, columns)
     |> assign(:analysis, analysis)
     |> assign(:mapping_errors, errors)
     |> assign(:plan, build_plan(analysis))}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :upload)
     |> assign(:analysis, nil)
     |> assign(:rows, [])
     |> assign(:columns, [])
     |> assign(:mapping_errors, [])
     |> assign(:plan, %{
       valid: [],
       errors: [],
       sample: [],
       total: 0,
       invalid: 0,
       blank: 0,
       emails_cleared: 0
     })}
  end

  def handle_event("import", _params, socket) do
    if socket.assigns.mapping_errors != [] do
      {:noreply, put_flash(socket, :error, "Corrija o mapeamento antes de importar.")}
    else
      case Events.import_participants(
             socket.assigns.current_scope,
             socket.assigns.batch,
             socket.assigns.plan.valid
           ) do
        {:ok, inserted} ->
          {:noreply,
           socket
           |> assign(:step, :result)
           |> assign(:result, %{
             inserted: inserted,
             errors: socket.assigns.plan.invalid,
             emails_cleared: socket.assigns.plan.emails_cleared
           })}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Não foi possível importar os participantes.")}
      end
    end
  end

  defp build_plan(analysis) do
    header_offset = if analysis.header_row, do: analysis.header_row, else: -1
    ParticipantPlan.build(analysis.data, analysis.columns, header_offset)
  end

  defp consume_file(socket) do
    case socket.assigns.uploads.planilha.entries do
      [] ->
        {:error, "Selecione um arquivo CSV ou XLSX."}

      [_entry] ->
        results =
          consume_uploaded_entries(socket, :planilha, fn %{path: path}, entry ->
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

  defp kind_from_params("name", _default), do: :name
  defp kind_from_params("email", _default), do: :email
  defp kind_from_params("ignore", _default), do: :ignore
  defp kind_from_params("extra", _default), do: :extra
  defp kind_from_params(_value, default), do: default

  defp import_confirm(%{invalid: 0}), do: nil

  defp import_confirm(%{invalid: count}),
    do: "#{count} linha(s) com erro serão ignoradas. Continuar?"

  defp spreadsheet_error(:too_large), do: "O arquivo é maior que 5 MB."
  defp spreadsheet_error(:parse_error), do: "Não foi possível interpretar o CSV."
  defp spreadsheet_error(:invalid_xlsx), do: "Não foi possível ler o arquivo XLSX."
  defp spreadsheet_error(_reason), do: "Não foi possível ler a planilha."

  defp upload_error(:too_large), do: "Arquivo maior que 5 MB."
  defp upload_error(:not_accepted), do: "Envie um arquivo .csv ou .xlsx."
  defp upload_error(:too_many_files), do: "Envie apenas um arquivo."
  defp upload_error(error), do: "Falha no upload: #{inspect(error)}"
end
