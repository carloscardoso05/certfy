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
    has_one :certificate, Certfy.Certificates.Certificate

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(participant, attrs, user_scope) do
    participant
    |> cast(attrs, [:name, :email, :extra_data])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:name])
    |> validate_length(:name, max: 160)
    |> validate_email_format(:email)
    |> foreign_key_constraint(:batch_id)
    |> foreign_key_constraint(:user_id)
    |> put_change(:user_id, user_scope.user.id)
  end

  defp normalize_email(nil), do: nil

  defp normalize_email(email) when is_binary(email) do
    case String.trim(email) do
      "" -> nil
      email -> email
    end
  end
end
