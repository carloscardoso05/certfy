defmodule Certfy.Repo.Migrations.CreateBatches do
  use Ecto.Migration

  def change do
    create table(:batches) do
      add :name, :citext
      add :extra_data, :map, default: %{}, null: false
      add :event_id, references(:events, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:batches, [:user_id])

    create unique_index(:batches, [:event_id, :name])
    create index(:batches, [:event_id])
  end
end
