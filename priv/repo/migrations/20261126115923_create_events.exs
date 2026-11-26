defmodule Certfy.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :name, :citext, null: false
      add :template_path, :string
      add :extra_data, :map, default: %{}, null: false
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:events, [:user_id])

    create unique_index(:events, [:user_id, :name])
  end
end
