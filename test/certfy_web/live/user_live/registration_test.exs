defmodule CertfyWeb.UserLive.RegistrationTest do
  use CertfyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Certfy.AccountsFixtures

  alias Certfy.Accounts

  describe "invitation registration" do
    setup do
      %{admin_scope: admin_scope_fixture()}
    end

    test "renders registration page for a valid invitation", %{
      conn: conn,
      admin_scope: scope
    } do
      %{token: token, invitation: invitation} = invitation_fixture(scope)

      {:ok, _lv, html} = live(conn, ~p"/users/register/#{token}")

      assert html =~ "Crie sua conta"
      assert html =~ invitation.email
    end

    test "redirects if the user is already logged in", %{
      conn: conn,
      admin_scope: scope
    } do
      %{token: token} = invitation_fixture(scope)
      user = user_fixture()
      logged_conn = log_in_user(conn, user)

      assert {:ok, _conn} =
               logged_conn
               |> live(~p"/users/register/#{token}")
               |> follow_redirect(logged_conn, ~p"/events")
    end

    test "renders errors for invalid name", %{conn: conn, admin_scope: scope} do
      %{token: token} = invitation_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/users/register/#{token}")

      result =
        lv
        |> form("#registration_form", user: %{"name" => ""})
        |> render_submit()

      assert result =~ "não pode ficar em branco"
    end

    test "creates the account and logs the user in", %{conn: conn, admin_scope: scope} do
      %{token: token, invitation: invitation} = invitation_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/users/register/#{token}")

      form = form(lv, "#registration_form", user: %{"name" => "Maria Silva"})
      render_submit(form)

      # Re-read the form so the hidden login token added by the server is included
      form = form(lv, "#registration_form")
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/events"

      user = Accounts.get_user_by_email(invitation.email)
      assert user.name == "Maria Silva"
      assert user.confirmed_at
      assert user.role == :USER
      assert get_session(conn, :user_token)
      refute Accounts.get_invitation_by_token(token)
    end

    test "rejects an invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/users/register/invalid")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "O convite é inválido ou expirou"
    end

    test "does not allow using the same invitation twice", %{
      conn: conn,
      admin_scope: scope
    } do
      %{token: token} = invitation_fixture(scope)

      {:ok, lv, _html} = live(conn, ~p"/users/register/#{token}")
      form = form(lv, "#registration_form", user: %{"name" => "Maria Silva"})
      render_submit(form)
      form = form(lv, "#registration_form")
      follow_trigger_action(form, conn)

      {:ok, _lv, html} =
        build_conn()
        |> live(~p"/users/register/#{token}")
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "O convite é inválido ou expirou"
    end
  end
end
