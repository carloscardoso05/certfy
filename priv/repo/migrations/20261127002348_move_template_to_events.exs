defmodule Certfy.Repo.Migrations.MoveTemplateToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :template_id, references(:certificate_templates, on_delete: :nilify_all)
      remove :template_path
    end

    create index(:events, [:template_id])
  end
end
