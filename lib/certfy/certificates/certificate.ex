defmodule Certfy.Certificates.Certificate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "certificates" do
    field :code, :string
    field :status, Ecto.Enum, values: [:pending, :processing, :ready, :failed], default: :pending

    field :email_status, Ecto.Enum,
      values: [:pending, :sent, :skipped, :failed],
      default: :pending

    field :pdf_path, :string
    field :page_count, :integer
    field :version, :integer, default: 1
    field :snapshot, :map, default: %{}
    field :warnings, {:array, :string}, default: []
    field :error, :string
    field :email_error, :string
    field :generated_at, :utc_datetime
    field :emailed_at, :utc_datetime
    field :user_id, :id

    belongs_to :event, Certfy.Events.Event
    belongs_to :batch, Certfy.Events.Batch
    belongs_to :participant, Certfy.Events.Participant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(certificate, attrs) do
    certificate
    |> cast(attrs, [
      :code,
      :status,
      :email_status,
      :pdf_path,
      :page_count,
      :version,
      :snapshot,
      :warnings,
      :error,
      :email_error,
      :generated_at,
      :emailed_at
    ])
    |> validate_required([:code])
    |> unique_constraint(:code)
    |> unique_constraint(:participant_id)
  end
end
