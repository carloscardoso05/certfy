defmodule CertfyWeb.UserLive.Registration do
  use CertfyWeb, :live_view

  alias Certfy.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-md">
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <.header>
              Crie sua conta
              <:subtitle>Você foi convidado a acessar o Certfy.</:subtitle>
            </.header>

            <.form
              for={@form}
              id="registration_form"
              action={~p"/users/log-in"}
              phx-submit="save"
              phx-trigger-action={@trigger_submit}
              class="space-y-3"
            >
              <input type="hidden" name="user[token]" value={@login_token} />

              <div class="fieldset mb-2">
                <label>
                  <span class="label mb-1">E-mail</span>
                  <input class="input w-full" type="email" value={@invitation.email} disabled />
                </label>
              </div>

              <.input
                field={@form[:name]}
                type="text"
                label="Nome"
                autocomplete="name"
                required
                phx-mounted={JS.focus()}
              />

              <.button class="btn btn-primary w-full" phx-disable-with="Criando conta...">
                Criar conta
              </.button>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => _token}, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ~p"/events")}
  end

  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_invitation_by_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "O convite é inválido ou expirou.")
         |> push_navigate(to: ~p"/users/log-in")}

      invitation ->
        {:ok,
         socket
         |> assign(:page_title, "Criar conta")
         |> assign(:invitation, invitation)
         |> assign(:invitation_token, token)
         |> assign(:login_token, nil)
         |> assign(:trigger_submit, false)
         |> assign(:form, to_form(%{"name" => ""}, as: "user"))}
    end
  end

  @impl true
  def handle_event("save", %{"user" => %{"name" => name}}, socket) do
    case Accounts.accept_invitation(socket.assigns.invitation_token, %{name: name}) do
      {:ok, user} ->
        login_token = Accounts.build_login_token(user)

        {:noreply,
         socket
         |> assign(:login_token, login_token)
         |> assign(:trigger_submit, true)}

      {:error, :invalid_invitation} ->
        {:noreply,
         socket
         |> put_flash(:error, "O convite é inválido ou expirou.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end
end
