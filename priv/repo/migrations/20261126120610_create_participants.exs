defmodule Certfy.Repo.Migrations.CreateParticipants do
  use Ecto.Migration

  def change do
    create table(:participants) do
      add :name, :citext, null: false
      add :email, :citext
      add :extra_data, :map, default: %{}, null: false
      add :batch_id, references(:batches, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:participants, [:user_id])

    create index(:participants, [:batch_id])
  end
end
