defmodule Certfy.Accounts.UserNotifier do
  import Swoosh.Email

  alias Certfy.Branding
  alias Certfy.Mailer
  alias Certfy.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({Branding.name(), Branding.from_email()})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Instruções para alterar e-mail", """

    ==============================

    Olá, #{user.email},

    Você pode alterar seu e-mail acessando o link abaixo:

    #{url}

    Se você não solicitou esta alteração, por favor ignore este e-mail.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Instruções de acesso", """

    ==============================

    Olá, #{user.email},

    Você pode entrar na sua conta acessando o link abaixo:

    #{url}

    Se você não solicitou este e-mail, por favor ignore-o.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Instruções de confirmação", """

    ==============================

    Olá, #{user.email},

    Você pode confirmar sua conta acessando o link abaixo:

    #{url}

    Se você não criou uma conta, por favor ignore este e-mail.

    ==============================
    """)
  end

  @doc """
  Delivers an invitation so the person can create an account.
  """
  def deliver_invitation_instructions(invitation, url, invited_by) do
    deliver(invitation.email, "Convite para acessar o #{Branding.name()}", """

    ==============================

    Olá,

    #{invited_by.name} te convidou para acessar o #{Branding.name()}.

    Crie sua conta acessando o link abaixo (válido por 7 dias):

    #{url}

    Se você não esperava este convite, por favor ignore este e-mail.

    ==============================
    """)
  end
end
