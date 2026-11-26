defmodule Certfy.Repo.Migrations.CreateUsersInvitations do
  use Ecto.Migration

  def change do
    create table(:users_invitations) do
      add :email, :citext, null: false
      add :token, :binary, null: false
      add :accepted_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :invited_by_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users_invitations, [:token])
    create index(:users_invitations, [:email])
    create index(:users_invitations, [:invited_by_id])
  end
end
