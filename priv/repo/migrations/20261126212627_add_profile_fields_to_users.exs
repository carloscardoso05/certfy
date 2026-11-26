defmodule Certfy.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
      add :role, :string, null: false, default: "USER"
      add :deactivated_at, :utc_datetime
    end

    execute "UPDATE users SET name = split_part(email::text, '@', 1)", ""

    alter table(:users) do
      modify :name, :string, null: false
    end

    create index(:users, [:role])
  end
end
