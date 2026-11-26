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
  def changeset(event, attrs, user_scope, opts \\ []) do
    event
    |> cast(attrs, [:name, :extra_data])
    |> validate_required([:name])
    |> foreign_key_constraint(:user_id)
    |> put_change(:user_id, user_scope.user.id)
    |> put_template_path(opts)
    |> unique_constraint([:user_id, :name])
  end

  defp put_template_path(changeset, opts) do
    case Keyword.fetch(opts, :template_path) do
      {:ok, template_path} -> put_change(changeset, :template_path, template_path)
      :error -> changeset
    end
  end
end
