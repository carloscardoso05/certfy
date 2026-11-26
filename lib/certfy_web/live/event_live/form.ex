defmodule CertfyWeb.EventLive.Form do
  use CertfyWeb, :live_view

  require Logger

  alias Certfy.Events
  alias Certfy.Events.Event

  @max_template_size 10_000_000
  @template_extension ".pptx"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        {@page_title}
        <:subtitle>Preencha os dados do evento e, se quiser, envie o template.</:subtitle>
      </.header>

      <div class="mx-auto w-full max-w-2xl">
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <.form
              for={@form}
              id="event-form"
              phx-change="validate"
              phx-submit="save"
              phx-drop-target={@uploads.template.ref}
              class="space-y-6"
            >
              <section>
                <h2 class="mb-2 text-sm font-semibold text-base-content/70">
                  Informações do evento
                </h2>
                <.input field={@form[:name]} type="text" label="Nome" required />
              </section>

              <section class="rounded-box border border-dashed border-base-300 p-4">
                <label class="label" for={@uploads.template.ref}>
                  Arquivo de template (.pptx)
                </label>
                <.live_file_input
                  upload={@uploads.template}
                  class="file-input file-input-bordered w-full"
                />
                <p :if={@event.template_path} class="mt-2 text-sm text-base-content/70">
                  Template já enviado.
                </p>

                <p :for={error <- upload_errors(@uploads.template)} class="mt-2 text-sm text-error">
                  {upload_error_to_string(error)}
                </p>

                <div :for={entry <- @uploads.template.entries}>
                  <p class="mt-2 text-sm">{entry.client_name} ({entry.progress}%)</p>

                  <p
                    :for={error <- upload_errors(@uploads.template, entry)}
                    class="mt-2 text-sm text-error"
                  >
                    {upload_error_to_string(error)}
                  </p>
                </div>
              </section>

              <footer class="flex flex-wrap justify-end gap-2">
                <.button navigate={return_path(@current_scope, @return_to, @event)}>
                  Cancelar
                </.button>
                <.button phx-disable-with="Salvando..." variant="primary">
                  Salvar evento
                </.button>
              </footer>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> allow_upload(:template,
       accept: ~w(.pptx),
       max_entries: 1,
       max_file_size: @max_template_size
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    event = Events.get_event!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Editar evento")
    |> assign(:event, event)
    |> assign(:form, to_form(Events.change_event(socket.assigns.current_scope, event)))
  end

  defp apply_action(socket, :new, _params) do
    event = %Event{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "Novo evento")
    |> assign(:event, event)
    |> assign(:form, to_form(Events.change_event(socket.assigns.current_scope, event)))
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      Events.change_event(socket.assigns.current_scope, socket.assigns.event, event_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"event" => event_params}, socket) do
    case store_template(socket) do
      {:ok, template_path} ->
        save_event(socket, socket.assigns.live_action, event_params, template_path)

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp save_event(socket, :edit, event_params, template_path) do
    opts = template_path_opts(template_path)

    case Events.update_event(
           socket.assigns.current_scope,
           socket.assigns.event,
           event_params,
           opts
         ) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento atualizado com sucesso.")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, event)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_event(socket, :new, event_params, template_path) do
    opts = template_path_opts(template_path)

    case Events.create_event(socket.assigns.current_scope, event_params, opts) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento criado com sucesso.")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, event)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp template_path_opts(nil), do: []
  defp template_path_opts(template_path), do: [template_path: template_path]

  defp store_template(socket) do
    upload = socket.assigns.uploads.template

    errors =
      (upload_errors(upload) ++ Enum.flat_map(upload.entries, &upload_errors(upload, &1)))
      |> Enum.uniq()

    if errors == [] do
      consume_template(socket)
    else
      {:error, Enum.map_join(errors, ", ", &upload_error_to_string/1)}
    end
  end

  defp consume_template(socket) do
    results =
      consume_uploaded_entries(socket, :template, fn %{path: path}, entry ->
        store_uploaded_entry(path, entry.client_name, entry.client_type)
      end)

    case results do
      [{:error, :not_accepted}] ->
        {:error, "Apenas arquivos #{@template_extension} são aceitos."}

      [{:error, _reason}] ->
        {:error, "Não foi possível enviar o arquivo de template."}

      [key] ->
        {:ok, key}

      [] ->
        {:ok, nil}

      _results ->
        {:error, "Não foi possível enviar o arquivo de template."}
    end
  end

  defp store_uploaded_entry(path, name, type) do
    if String.downcase(Path.extname(name)) == @template_extension do
      store_valid_template(path, name, type)
    else
      {:ok, {:error, :not_accepted}}
    end
  end

  defp store_valid_template(path, name, type) do
    with {:ok, body} <- File.read(path) do
      key = Certfy.Storage.template_key(name)
      content_type = if type in [nil, ""], do: "application/octet-stream", else: type

      case Certfy.Storage.put_template(key, body, content_type) do
        {:ok, _key} ->
          {:ok, key}

        {:error, reason} ->
          Logger.error("Could not upload template to RustFS: #{inspect(reason)}")
          {:ok, {:error, :upload_failed}}
      end
    else
      {:error, reason} ->
        Logger.error("Could not read uploaded template: #{inspect(reason)}")
        {:ok, {:error, :read_failed}}
    end
  end

  defp upload_error_to_string(:too_large) do
    "O arquivo é muito grande (máximo de #{div(@max_template_size, 1_000_000)} MB)"
  end

  defp upload_error_to_string(:not_accepted) do
    "Apenas arquivos #{@template_extension} são aceitos"
  end

  defp upload_error_to_string(:too_many_files), do: "Apenas um arquivo é permitido"
  defp upload_error_to_string(:external_client_failure), do: "Falha no envio"

  defp upload_error_to_string({:writer_failure, _reason}), do: "Falha no envio"
  defp upload_error_to_string(error), do: "Erro no envio: #{inspect(error)}"

  defp return_path(_scope, "index", _event), do: ~p"/events"
  defp return_path(_scope, "show", event), do: ~p"/events/#{event}"
end
