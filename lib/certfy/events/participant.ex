defmodule Certfy.Events.Participant do
  alias Certfy.Events.Batch
  use Ecto.Schema
  import Ecto.Changeset
  import Certfy.Validators

  schema "participants" do
    field :name, :string
    field :email, :string
    field :extra_data, :map, default: %{}
    field :user_id, :id

    belongs_to :batch, Batch

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(participant, attrs, user_scope) do
    participant
    |> cast(attrs, [:name, :email, :extra_data])
    |> validate_required([:name, :email])
    |> validate_email_format(:email)
    |> foreign_key_constraint(:batch_id)
    |> foreign_key_constraint(:user_id)
    |> put_change(:user_id, user_scope.user.id)
  end
end
