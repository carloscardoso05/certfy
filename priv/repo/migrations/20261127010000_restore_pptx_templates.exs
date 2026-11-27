defmodule Certfy.Repo.Migrations.RestorePptxTemplates do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :template_path, :string
      add :template_report, :map, null: false, default: %{}
      add :template_checked_at, :utc_datetime
      remove :template_id
    end

    alter table(:certificates) do
      remove :template_id
      remove :template_version
    end

    drop table(:certificate_templates)
  end
end
