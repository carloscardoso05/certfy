defmodule Certfy.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Certfy.Validators

  schema "users" do
    field :name, :string
    field :role, Ecto.Enum, values: [:USER, :ADMIN], default: :USER
    field :email, :string
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :deactivated_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It requires a name and an email. Role and confirmation are set by the
  caller, never by user input.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:name, :email])
    |> update_change(:name, &trim_name/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_email(opts)
  end

  @doc """
  A user changeset for changing the displayed name.
  """
  def name_changeset(user, attrs) do
    user
    |> cast(attrs, [:name])
    |> update_change(:name, &trim_name/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 120)
  end

  @doc """
  A user changeset for changing the role. Only admins can call this.
  """
  def role_changeset(user, role) do
    user
    |> cast(%{role: role}, [:role])
    |> validate_required([:role])
  end

  @doc """
  A user changeset for deactivating or reactivating the account.
  """
  def deactivation_changeset(user, deactivated_at) do
    change(user, deactivated_at: deactivated_at)
  end

  def deactivated?(%__MODULE__{deactivated_at: nil}), do: false
  def deactivated?(%__MODULE__{}), do: true

  defp trim_name(nil), do: nil
  defp trim_name(name) when is_binary(name), do: String.trim(name)

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_email_format(:email)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Certfy.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end
end
