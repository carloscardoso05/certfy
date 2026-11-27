defmodule CertfyWeb.UserLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Accounts.Admin
  alias CertfyWeb.UserAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} nav={:users}>
      <.header>
        Usuários
        <:subtitle>Gerencie quem tem acesso ao {Certfy.Branding.name()}.</:subtitle>
      </.header>

      <.form for={@filter_form} id="user-filters" phx-change="filter" class="mb-4">
        <div class="grid gap-3 md:grid-cols-[minmax(0,1fr)_11rem_11rem] md:items-end">
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

          <label class="block">
            <span class="mb-1 block text-sm font-medium">Perfil</span>
            <select name="role" class="select select-bordered w-full">
              <option value="all" selected={@filters["role"] == "all"}>Todos</option>

              <option value="ADMIN" selected={@filters["role"] == "ADMIN"}>Admin</option>

              <option value="USER" selected={@filters["role"] == "USER"}>Usuário</option>
            </select>
          </label>

          <label class="block">
            <span class="mb-1 block text-sm font-medium">Status</span>
            <select name="status" class="select select-bordered w-full">
              <option value="all" selected={@filters["status"] == "all"}>Todos</option>

              <option value="active" selected={@filters["status"] == "active"}>Ativos</option>

              <option value="deactivated" selected={@filters["status"] == "deactivated"}>
                Desativados
              </option>
            </select>
          </label>
        </div>
      </.form>

      <div class="space-y-6">
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-base">Convidar usuário</h2>

            <p class="text-sm text-base-content/70">
              Envie um link por e-mail para a pessoa criar a conta.
            </p>

            <.form for={@invite_form} id="invite-form" phx-submit="invite" class="mt-2 space-y-3">
              <.input field={@invite_form[:email]} type="email" label="E-mail" required />
              <.button variant="primary" class="w-full" phx-disable-with="Enviando...">
                Enviar convite
              </.button>
            </.form>
          </div>
        </div>

        <div class="card bg-base-100 shadow-sm">
          <div class="card-body p-0">
            <div id="users" phx-update="stream" class="divide-y divide-base-300">
              <div
                :for={{id, user} <- @streams.users}
                id={id}
                class="grid gap-3 px-4 py-4 md:grid-cols-[minmax(0,1fr)_7rem_7rem_15rem] md:items-center"
              >
                <div class="min-w-0">
                  <p class="truncate text-base font-medium">{user.name}</p>

                  <p class="truncate text-sm text-base-content/70">{user.email}</p>
                </div>

                <div>
                  <span class={role_badge(user.role)}>{role_label(user.role)}</span>
                </div>

                <div>
                  <span class={status_badge(user)}>{status_label(user)}</span>
                </div>

                <div class="flex flex-col gap-1">
                  <%= if user.id == @current_scope.user.id do %>
                    <span class="badge badge-outline badge-sm self-start">Você</span>
                  <% else %>
                    <button
                      type="button"
                      class="btn btn-soft"
                      phx-click="change_role"
                      phx-value-id={user.id}
                      phx-value-role={if user.role == :ADMIN, do: "USER", else: "ADMIN"}
                    >
                      {if user.role == :ADMIN, do: "Tornar usuário", else: "Tornar admin"}
                    </button>

                    <button
                      :if={is_nil(user.deactivated_at)}
                      type="button"
                      class="btn btn-soft btn-error"
                      phx-click="deactivate"
                      phx-value-id={user.id}
                      data-confirm="Desativar este usuário? Ele perderá o acesso imediatamente."
                    >
                      Desativar
                    </button>

                    <button
                      :if={user.deactivated_at}
                      type="button"
                      class="btn btn-soft"
                      phx-click="reactivate"
                      phx-value-id={user.id}
                    >
                      Reativar
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="card mt-6 bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title text-base">Convites pendentes</h2>

          <div
            :if={@invitations_empty?}
            class="rounded-box border border-dashed border-base-300 p-6 text-center text-sm text-base-content/60"
          >
            Nenhum convite pendente.
          </div>

          <div :if={!@invitations_empty?} class="divide-y divide-base-300">
            <div id="invitations" phx-update="stream">
              <div
                :for={{id, invitation} <- @streams.invitations}
                id={id}
                class="grid gap-3 py-4 md:grid-cols-[minmax(0,1fr)_10rem_9rem_11rem] md:items-center"
              >
                <div class="min-w-0">
                  <p class="truncate text-base font-medium">{invitation.email}</p>
                </div>

                <div class="text-sm text-base-content/70">
                  {invitation.invited_by.name}
                </div>

                <div class="text-sm text-base-content/70">
                  {format_datetime(invitation.expires_at)}
                </div>

                <div class="flex flex-col gap-1">
                  <button
                    type="button"
                    class="btn btn-soft"
                    phx-click="resend_invitation"
                    phx-value-id={invitation.id}
                  >
                    Reenviar
                  </button>

                  <button
                    type="button"
                    class="btn btn-soft btn-error"
                    phx-click="revoke_invitation"
                    phx-value-id={invitation.id}
                    data-confirm="Revogar este convite? O link deixará de funcionar."
                  >
                    Revogar
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    filters = %{"q" => "", "role" => "all", "status" => "all"}

    {:ok,
     socket
     |> assign(:page_title, "Usuários")
     |> assign(:invite_form, to_form(%{"email" => ""}, as: "invitation"))
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters))
     |> load_users()
     |> refresh_invitations()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      "q" => params["q"] || "",
      "role" => params["role"] || "all",
      "status" => params["status"] || "all"
    }

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters))
     |> load_users()
     |> refresh_invitations()}
  end

  def handle_event("resend_invitation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    invitation = Admin.get_invitation(scope, id)

    case invitation &&
           Admin.resend_invitation(scope, invitation, &url(~p"/users/register/#{&1}")) do
      {:ok, invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Convite reenviado para #{invitation.email}.")
         |> refresh_invitations()}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível reenviar o convite.")}
    end
  end

  def handle_event("revoke_invitation", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    invitation = Admin.get_invitation(scope, id)

    case invitation && Admin.revoke_invitation(scope, invitation) do
      {:ok, _invitation} ->
        {:noreply, socket |> put_flash(:info, "Convite revogado.") |> refresh_invitations()}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível revogar o convite.")}
    end
  end

  @impl true
  def handle_event("invite", %{"invitation" => %{"email" => email}}, socket) do
    scope = socket.assigns.current_scope

    case Admin.invite_user(scope, email, &url(~p"/users/register/#{&1}")) do
      {:ok, invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Convite enviado para #{invitation.email}.")
         |> assign(:invite_form, to_form(%{"email" => ""}, as: "invitation"))
         |> refresh_invitations()}

      {:error, :already_registered} ->
        {:noreply, put_flash(socket, :error, "Já existe um usuário com este e-mail.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :invite_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    user = Admin.get_user(scope, id)

    case user && Admin.deactivate_user(scope, user) do
      {:ok, {_user, expired_tokens}} ->
        UserAuth.disconnect_sessions(expired_tokens)

        {:noreply,
         socket
         |> put_flash(:info, "Usuário desativado.")
         |> refresh_users()}

      {:error, :cannot_modify_self} ->
        {:noreply, put_flash(socket, :error, "Você não pode desativar a própria conta.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível desativar o usuário.")}
    end
  end

  def handle_event("reactivate", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    user = Admin.get_user(scope, id)

    case user && Admin.reactivate_user(scope, user) do
      {:ok, _user} ->
        {:noreply, socket |> put_flash(:info, "Usuário reativado.") |> refresh_users()}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível reativar o usuário.")}
    end
  end

  def handle_event("change_role", %{"id" => id, "role" => role}, socket) do
    scope = socket.assigns.current_scope
    user = Admin.get_user(scope, id)
    role = role_from_string(role)

    case user && role && Admin.change_role(scope, user, role) do
      {:ok, _user} ->
        {:noreply, socket |> put_flash(:info, "Perfil atualizado.") |> refresh_users()}

      {:error, :cannot_modify_self} ->
        {:noreply,
         put_flash(socket, :error, "Você não pode remover seu próprio acesso de admin.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível atualizar o perfil.")}
    end
  end

  defp load_users(socket) do
    users = Admin.list_users(socket.assigns.current_scope, socket.assigns.filters)

    stream(socket, :users, users, reset: true)
  end

  defp refresh_users(socket) do
    load_users(socket)
  end

  defp refresh_invitations(socket) do
    scope = socket.assigns.current_scope
    invitations = Admin.list_pending_invitations(scope, socket.assigns.filters)

    socket
    |> assign(:invitations_empty?, invitations == [])
    |> stream(:invitations, invitations, reset: true)
  end

  defp role_from_string("ADMIN"), do: :ADMIN
  defp role_from_string("USER"), do: :USER
  defp role_from_string(_role), do: nil

  defp role_label(:ADMIN), do: "Admin"
  defp role_label(_role), do: "Usuário"

  defp role_badge(:ADMIN), do: "badge badge-primary badge-sm"
  defp role_badge(_role), do: "badge badge-ghost badge-sm"

  defp status_label(%{deactivated_at: nil}), do: "Ativo"
  defp status_label(_user), do: "Desativado"

  defp status_badge(%{deactivated_at: nil}), do: "badge badge-success badge-sm"
  defp status_badge(_user), do: "badge badge-error badge-sm"

  defp format_datetime(nil), do: "—"
  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%d/%m/%Y às %H:%M")
end
