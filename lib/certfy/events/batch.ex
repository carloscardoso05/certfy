defmodule Certfy.Events.Batch do
  alias Certfy.Events.Event
  alias Certfy.Events.Participant
  use Ecto.Schema
  import Ecto.Changeset

  schema "batches" do
    field :name, :string
    field :extra_data, :map, default: %{}
    field :user_id, :id

    belongs_to :event, Event
    has_many :participants, Participant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(batch, attrs, user_scope) do
    batch
    |> cast(attrs, [:name, :extra_data])
    |> validate_required([:name])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:event_id)
    |> unique_constraint([:event_id, :name])
    |> put_change(:user_id, user_scope.user.id)
  end
end
