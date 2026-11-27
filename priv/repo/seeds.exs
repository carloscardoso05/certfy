# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Certfy.Repo.insert!(%Certfy.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Certfy.Accounts
alias Certfy.Accounts.User
alias Certfy.Repo

admin_email =
  System.get_env("CERTFY_ADMIN_EMAIL") ||
    "admin@certfy.local"

now = DateTime.utc_now(:second)

changeset =
  case Accounts.get_user_by_email(admin_email) do
    nil ->
      %User{}
      |> User.email_changeset(%{email: admin_email})
      |> Ecto.Changeset.put_change(:name, "Administrador")
      |> Ecto.Changeset.put_change(:confirmed_at, now)

    user ->
      user
      |> Ecto.Changeset.change(confirmed_at: user.confirmed_at || now)
  end
  |> Ecto.Changeset.put_change(:role, :ADMIN)

user = Repo.insert_or_update!(changeset)
IO.puts("Admin pronto: #{user.email} (#{user.role})")
