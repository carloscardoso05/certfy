defmodule Certfy.Repo.Migrations.CreateCertificateTemplates do
  use Ecto.Migration

  def change do
    create table(:certificate_templates) do
      add :name, :citext, null: false
      add :schema, :map, null: false, default: %{"version" => 1, "pages" => []}
      add :page_count, :integer, null: false, default: 1
      add :version, :integer, null: false, default: 1
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:certificate_templates, [:user_id])
    create unique_index(:certificate_templates, [:user_id, :name])
  end
end
