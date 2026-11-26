defmodule CertfyWeb.UserSessionController do
  use CertfyWeb, :controller

  alias Certfy.Accounts
  alias CertfyWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Usuário confirmado com sucesso.")
  end

  def create(conn, params) do
    create(conn, params, "Bem-vindo(a) de volta!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "O link é inválido ou expirou.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp create(conn, _params, _info) do
    conn
    |> put_flash(:error, "O link é inválido ou expirou.")
    |> redirect(to: ~p"/users/log-in")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Sessão encerrada com sucesso.")
    |> UserAuth.log_out_user()
  end
end
