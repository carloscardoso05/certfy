defmodule Certfy.Events.Event do
  alias Certfy.Events.Batch
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :name, :string
    field :template_path, :string
    field :template_report, :map, default: %{}
    field :template_checked_at, :utc_datetime
    field :extra_data, :map, default: %{}
    field :user_id, :id

    has_many :batches, Batch
    has_many :certificates, Certfy.Certificates.Certificate

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, user_scope) do
    event
    |> cast(attrs, [:name, :extra_data])
    |> validate_required([:name])
    |> foreign_key_constraint(:user_id)
    |> put_change(:user_id, user_scope.user.id)
    |> unique_constraint([:user_id, :name])
  end

  @doc false
  def template_changeset(event, attrs) do
    event
    |> cast(attrs, [:template_path, :template_report, :template_checked_at])
  end
end
