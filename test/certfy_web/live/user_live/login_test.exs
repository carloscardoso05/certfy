defmodule CertfyWeb.UserLive.LoginTest do
  use CertfyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Certfy.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Entrar"
      assert html =~ "O acesso é por convite"
      assert html =~ "Entrar com e-mail"
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      html =
        lv
        |> form("#login_form_magic", user: %{email: user.email})
        |> render_submit()

      assert html =~ "Verifique seu e-mail"
      assert html =~ user.email

      assert Certfy.Repo.get_by!(Certfy.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      html =
        lv
        |> form("#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()

      assert html =~ "Verifique seu e-mail"
      assert html =~ "idonotexist@example.com"
    end

    test "lets the user go back to the email form", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      lv
      |> form("#login_form_magic", user: %{email: user.email})
      |> render_submit()

      html =
        lv
        |> element("button", "Usar outro e-mail")
        |> render_click()

      assert html =~ "Entrar com e-mail"
      refute html =~ "Verifique seu e-mail"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Você precisa se autenticar novamente"
      refute html =~ "O acesso é por convite"
      assert html =~ "Entrar com e-mail"

      assert html =~
               ~s(<input type="email" name="user[email]" id="login_form_magic_email" value="#{user.email}")
    end
  end
end
