defmodule Certfy.Repo.Migrations.CreateCertificates do
  use Ecto.Migration

  def change do
    create table(:certificates) do
      add :code, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :email_status, :string, null: false, default: "pending"
      add :pdf_path, :string
      add :page_count, :integer
      add :version, :integer, null: false, default: 1
      add :template_version, :integer
      add :snapshot, :map, null: false, default: %{}
      add :warnings, {:array, :string}, null: false, default: []
      add :error, :text
      add :email_error, :text
      add :generated_at, :utc_datetime
      add :emailed_at, :utc_datetime

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :batch_id, references(:batches, on_delete: :delete_all), null: false
      add :participant_id, references(:participants, on_delete: :delete_all), null: false
      add :template_id, references(:certificate_templates, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:certificates, [:participant_id])
    create unique_index(:certificates, [:code])
    create index(:certificates, [:user_id])
    create index(:certificates, [:batch_id, :status])
    create index(:certificates, [:event_id, :status])
  end
end
