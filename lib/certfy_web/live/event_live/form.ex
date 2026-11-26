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
        <:subtitle>Use this form to manage event records in your database.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="event-form"
        phx-change="validate"
        phx-submit="save"
        phx-drop-target={@uploads.template.ref}
      >
        <.input field={@form[:name]} type="text" label="Name" />

        <div class="mt-4">
          <label class="label" for={@uploads.template.ref}>Template file (.pptx)</label>
          <.live_file_input upload={@uploads.template} />
          <p :if={@event.template_path} class="mt-2 text-sm">
            Template already uploaded.
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
        </div>

        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Event</.button>
          <.button navigate={return_path(@current_scope, @return_to, @event)}>Cancel</.button>
        </footer>
      </.form>
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
    |> assign(:page_title, "Edit Event")
    |> assign(:event, event)
    |> assign(:form, to_form(Events.change_event(socket.assigns.current_scope, event)))
  end

  defp apply_action(socket, :new, _params) do
    event = %Event{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Event")
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
         |> put_flash(:info, "Event updated successfully")
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
         |> put_flash(:info, "Event created successfully")
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
        {:error, "Only #{@template_extension} files are accepted."}

      [{:error, _reason}] ->
        {:error, "Could not upload the template file."}

      [key] ->
        {:ok, key}

      [] ->
        {:ok, nil}

      _results ->
        {:error, "Could not upload the template file."}
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
    "File is too large (max #{div(@max_template_size, 1_000_000)} MB)"
  end

  defp upload_error_to_string(:not_accepted) do
    "Only #{@template_extension} files are accepted"
  end

  defp upload_error_to_string(:too_many_files), do: "Only one file is allowed"
  defp upload_error_to_string(:external_client_failure), do: "Upload failed"

  defp upload_error_to_string({:writer_failure, _reason}), do: "Upload failed"
  defp upload_error_to_string(error), do: "Upload error: #{inspect(error)}"

  defp return_path(_scope, "index", _event), do: ~p"/events"
  defp return_path(_scope, "show", event), do: ~p"/events/#{event}"
end
