defmodule CertfyWeb.UserLive.IndexTest do
  use CertfyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Certfy.AccountsFixtures

  alias Certfy.Accounts
  alias Certfy.Accounts.Admin

  describe "as an admin" do
    setup :register_and_log_in_admin

    test "lists users and pending invitations", %{conn: conn, user: admin} do
      other = user_fixture(%{name: "Outra Pessoa"})
      %{invitation: invitation} = invitation_fixture(Accounts.Scope.for_user(admin))

      {:ok, _lv, html} = live(conn, ~p"/users")

      assert html =~ "Usuários"
      assert html =~ "Convidar usuário"
      assert html =~ admin.email
      assert html =~ other.name
      assert html =~ invitation.email
    end

    test "invites an email", %{conn: conn, user: admin} do
      {:ok, lv, _html} = live(conn, ~p"/users")

      form = form(lv, "#invite-form", invitation: %{email: "convidado@example.com"})
      html = render_submit(form)

      assert html =~ "Convite enviado para convidado@example.com"

      invitations = Admin.list_pending_invitations(Accounts.Scope.for_user(admin))
      assert Enum.any?(invitations, &(&1.email == "convidado@example.com"))
    end

    test "validates the invited email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users")

      result =
        lv
        |> form("#invite-form", invitation: %{email: "com espaços"})
        |> render_submit()

      assert result =~ "deve conter @ e não conter espaços"
    end

    test "does not invite an existing user", %{conn: conn} do
      other = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users")

      result =
        lv
        |> form("#invite-form", invitation: %{email: other.email})
        |> render_submit()

      assert result =~ "Já existe um usuário com este e-mail"
    end

    test "deactivates and reactivates a user", %{conn: conn} do
      other = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users")

      lv
      |> element("#users-#{other.id} button", "Desativar")
      |> render_click()

      assert Accounts.get_user!(other.id).deactivated_at

      lv
      |> element("#users-#{other.id} button", "Reativar")
      |> render_click()

      refute Accounts.get_user!(other.id).deactivated_at
    end

    test "changes a user role", %{conn: conn} do
      other = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users")

      lv
      |> element("#users-#{other.id} button", "Tornar admin")
      |> render_click()

      assert Accounts.get_user!(other.id).role == :ADMIN
    end

    test "filters users by name", %{conn: conn, user: admin} do
      other = user_fixture(%{name: "Alvo Especial"})

      {:ok, lv, _html} = live(conn, ~p"/users")

      lv
      |> form("#user-filters", %{"q" => "Alvo Especial"})
      |> render_change()

      assert has_element?(lv, "#users-#{other.id}")
      refute has_element?(lv, "#users-#{admin.id}")
    end

    test "resends a pending invitation", %{conn: conn, user: admin} do
      %{invitation: invitation} = invitation_fixture(Accounts.Scope.for_user(admin))

      {:ok, lv, _html} = live(conn, ~p"/users")

      html =
        lv
        |> element("#invitations-#{invitation.id} button", "Reenviar")
        |> render_click()

      assert html =~ "Convite reenviado"

      pending = Admin.list_pending_invitations(Accounts.Scope.for_user(admin))
      assert length(pending) == 1
      refute Enum.any?(pending, &(&1.id == invitation.id))
    end

    test "revokes a pending invitation", %{conn: conn, user: admin} do
      %{invitation: invitation} = invitation_fixture(Accounts.Scope.for_user(admin))

      {:ok, lv, _html} = live(conn, ~p"/users")

      html =
        lv
        |> element("#invitations-#{invitation.id} button", "Revogar")
        |> render_click()

      assert html =~ "Convite revogado."
      assert Admin.list_pending_invitations(Accounts.Scope.for_user(admin)) == []
    end
  end

  describe "as a regular user" do
    setup :register_and_log_in_user

    test "cannot access the users page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/events", flash: flash}}} = live(conn, ~p"/users")

      assert flash["error"] == "Você não tem permissão para acessar esta página."
    end
  end

  describe "as a guest" do
    test "is redirected to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/users")
    end
  end
end
