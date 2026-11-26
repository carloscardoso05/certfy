defmodule Certfy.Events.Event do
  alias Certfy.Events.Batch
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :name, :string
    field :template_path, :string
    field :extra_data, :map, default: %{}
    field :user_id, :id

    has_many :batches, Batch

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, user_scope) do
    event
    |> cast(attrs, [:name, :template_path, :extra_data])
    |> validate_required([:name])
    |> foreign_key_constraint(:user_id)
    |> put_change(:user_id, user_scope.user.id)
    |> unique_constraint([:user_id, :name])
  end
end
