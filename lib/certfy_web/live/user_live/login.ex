defmodule CertfyWeb.UserLive.Login do
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
              Entrar
              <:subtitle>
                <%= if @current_scope do %>
                  Você precisa se autenticar novamente para realizar ações sensíveis na sua conta.
                <% else %>
                  Acesse sua conta para continuar.
                <% end %>
              </:subtitle>
            </.header>

            <div :if={local_mail_adapter?()} class="alert alert-info mb-4">
              <.icon name="hero-information-circle" class="size-6 shrink-0" />
              <div>
                <p>Você está usando o adaptador de e-mail local.</p>

                <p>
                  Para ver os e-mails enviados, acesse <.link href="/dev/mailbox" class="underline">a página da caixa de entrada</.link>.
                </p>
              </div>
            </div>

            <.form
              :let={f}
              for={@form}
              id="login_form_magic"
              action={~p"/users/log-in"}
              phx-submit="submit_magic"
              class="space-y-3"
            >
              <.input
                readonly={!!@current_scope}
                field={f[:email]}
                type="email"
                label="E-mail"
                autocomplete="username"
                spellcheck="false"
                required
                phx-mounted={JS.focus()}
              />
              <.button class="btn btn-primary w-full">
                Entrar com e-mail <span aria-hidden="true">→</span>
              </.button>
            </.form>

            <p :if={is_nil(@current_scope)} class="mt-4 text-center text-sm text-base-content/60">
              O acesso é por convite. Fale com um administrador se precisar de uma conta.
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    case Accounts.get_user_by_email(email) do
      %{deactivated_at: nil} = user ->
        Accounts.deliver_login_instructions(
          user,
          &url(~p"/users/log-in/#{&1}")
        )

      _ ->
        :ok
    end

    info =
      "Se o seu e-mail estiver cadastrado, você receberá instruções de acesso em breve."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:certfy, Certfy.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
