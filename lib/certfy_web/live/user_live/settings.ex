defmodule CertfyWeb.UserLive.Settings do
  use CertfyWeb, :live_view

  on_mount {CertfyWeb.UserAuth, :require_sudo_mode}

  alias Certfy.Accounts
  alias Certfy.Accounts.Scope

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-2xl space-y-6">
        <.header>
          Configurações da conta
          <:subtitle>Gerencie seus dados de acesso.</:subtitle>
        </.header>

        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="card-title text-base">Perfil</h2>
                <p class="text-sm text-base-content/70">
                  Seu nome aparece na barra de navegação.
                </p>
              </div>
              <span class={role_badge(@current_scope.user.role)}>
                {role_label(@current_scope.user.role)}
              </span>
            </div>

            <.form
              for={@name_form}
              id="name_form"
              phx-submit="update_name"
              phx-change="validate_name"
              class="mt-2 space-y-3"
            >
              <.input
                field={@name_form[:name]}
                type="text"
                label="Nome"
                autocomplete="name"
                required
              />
              <.button variant="primary" phx-disable-with="Salvando...">Salvar nome</.button>
            </.form>

            <p class="mt-2 text-xs text-base-content/60">
              E-mail: {@current_scope.user.email}
            </p>
          </div>
        </div>

        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-base">E-mail</h2>
            <p class="text-sm text-base-content/70">
              Alterar o e-mail exige confirmação no novo endereço.
            </p>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
              class="mt-2 space-y-3"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label="E-mail"
                autocomplete="username"
                spellcheck="false"
                required
              />
              <.button variant="primary" phx-disable-with="Alterando...">Alterar e-mail</.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "E-mail alterado com sucesso.")

        {:error, _} ->
          put_flash(socket, :error, "O link de alteração de e-mail é inválido ou expirou.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)

    socket =
      socket
      |> assign(:name_form, to_form(Accounts.change_user_name(user)))
      |> assign(:email_form, to_form(email_changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_name", params, socket) do
    %{"user" => user_params} = params

    name_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, name_form: name_form)}
  end

  def handle_event("update_name", params, socket) do
    %{"user" => user_params} = params

    case Accounts.update_user_name(socket.assigns.current_scope.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(user))
         |> assign(:name_form, to_form(Accounts.change_user_name(user)))
         |> put_flash(:info, "Nome atualizado com sucesso.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :name_form, to_form(changeset, action: :insert))}
    end
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "Um link para confirmar a alteração de e-mail foi enviado para o novo endereço."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  defp role_label(:ADMIN), do: "Admin"
  defp role_label(_role), do: "Usuário"

  defp role_badge(:ADMIN), do: "badge badge-primary badge-sm"
  defp role_badge(_role), do: "badge badge-ghost badge-sm"
end
