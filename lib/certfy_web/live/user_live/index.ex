defmodule CertfyWeb.UserLive.Index do
  use CertfyWeb, :live_view

  alias Certfy.Accounts.Admin
  alias CertfyWeb.UserAuth

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Usuários
        <:subtitle>Gerencie quem tem acesso ao Certfy.</:subtitle>
      </.header>

      <div class="grid gap-6 lg:grid-cols-3">
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

        <div class="card bg-base-100 shadow-sm lg:col-span-2">
          <div class="card-body p-0">
            <div class="overflow-x-auto">
              <.table id="users" rows={@streams.users}>
                <:col :let={{_id, user}} label="Usuário">
                  <div>
                    <div class="font-medium">{user.name}</div>
                    <div class="text-xs text-base-content/60">{user.email}</div>
                  </div>
                </:col>
                <:col :let={{_id, user}} label="Perfil">
                  <span class={role_badge(user.role)}>{role_label(user.role)}</span>
                </:col>
                <:col :let={{_id, user}} label="Status">
                  <span class={status_badge(user)}>{status_label(user)}</span>
                </:col>
                <:action :let={{_id, user}}>
                  <%= if user.id == @current_scope.user.id do %>
                    <span class="badge badge-outline badge-sm">Você</span>
                  <% else %>
                    <div class="flex flex-wrap gap-1">
                      <button
                        type="button"
                        class="btn btn-ghost btn-xs"
                        phx-click="change_role"
                        phx-value-id={user.id}
                        phx-value-role={if user.role == :ADMIN, do: "USER", else: "ADMIN"}
                      >
                        {if user.role == :ADMIN, do: "Tornar usuário", else: "Tornar admin"}
                      </button>

                      <button
                        :if={is_nil(user.deactivated_at)}
                        type="button"
                        class="btn btn-ghost btn-xs text-error"
                        phx-click="deactivate"
                        phx-value-id={user.id}
                        data-confirm="Desativar este usuário? Ele perderá o acesso imediatamente."
                      >
                        Desativar
                      </button>

                      <button
                        :if={user.deactivated_at}
                        type="button"
                        class="btn btn-ghost btn-xs text-success"
                        phx-click="reactivate"
                        phx-value-id={user.id}
                      >
                        Reativar
                      </button>
                    </div>
                  <% end %>
                </:action>
              </.table>
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

          <div :if={!@invitations_empty?} class="overflow-x-auto">
            <.table id="invitations" rows={@streams.invitations}>
              <:col :let={{_id, invitation}} label="E-mail">{invitation.email}</:col>
              <:col :let={{_id, invitation}} label="Convidado por">
                {invitation.invited_by.name}
              </:col>
              <:col :let={{_id, invitation}} label="Expira em">
                {format_datetime(invitation.expires_at)}
              </:col>
            </.table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    users = Admin.list_users(scope)
    invitations = Admin.list_pending_invitations(scope)

    {:ok,
     socket
     |> assign(:page_title, "Usuários")
     |> assign(:invite_form, to_form(%{"email" => ""}, as: "invitation"))
     |> assign(:invitations_empty?, invitations == [])
     |> stream(:users, users)
     |> stream(:invitations, invitations)}
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

  defp refresh_users(socket) do
    stream(socket, :users, Admin.list_users(socket.assigns.current_scope), reset: true)
  end

  defp refresh_invitations(socket) do
    scope = socket.assigns.current_scope
    invitations = Admin.list_pending_invitations(scope)

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
