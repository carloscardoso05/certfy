defmodule Certfy.Events.Batch do
  alias Certfy.Events.Event
  alias Certfy.Events.Participant
  use Ecto.Schema
  import Ecto.Changeset

  schema "batches" do
    field :name, :string
    field :extra_data, :map, default: %{}
    field :user_id, :id
    field :participants_count, :integer, virtual: true

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
    |> put_owner(user_scope)
  end

  # An admin may edit records owned by other users, so the owner is only set
  # when the record is being created.
  defp put_owner(%Ecto.Changeset{data: %{user_id: nil}} = changeset, user_scope) do
    put_change(changeset, :user_id, user_scope.user.id)
  end

  defp put_owner(changeset, _user_scope), do: changeset
end
