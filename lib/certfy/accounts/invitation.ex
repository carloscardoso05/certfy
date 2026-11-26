defmodule Certfy.Accounts.Invitation do
  @moduledoc """
  An invitation sent by an admin so a person can create an account.

  Only the hashed token is stored. The plain token goes in the email link and
  is valid for 7 days.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  import Certfy.Validators

  @hash_algorithm :sha256
  @rand_size 32
  @validity_in_days 7

  schema "users_invitations" do
    field :email, :string
    field :token, :binary, redact: true
    field :accepted_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :invited_by, Certfy.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds an invitation and its plain token to be sent by email.
  """
  def build(email, invited_by_id) do
    token = :crypto.strong_rand_bytes(@rand_size)
    expires_at = DateTime.add(DateTime.utc_now(:second), @validity_in_days, :day)

    invitation = %__MODULE__{
      email: email,
      token: hash(token),
      expires_at: expires_at,
      invited_by_id: invited_by_id
    }

    {invitation, Base.url_encode64(token, padding: false)}
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email])
    |> update_change(:email, &String.trim/1)
    |> validate_required([:email])
    |> validate_email_format(:email)
  end

  def accept_changeset(invitation) do
    change(invitation, accepted_at: DateTime.utc_now(:second))
  end

  @doc """
  Returns a query for a valid (not accepted, not expired) invitation token.
  """
  def verify_token_query(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        now = DateTime.utc_now(:second)

        {:ok,
         from(i in __MODULE__,
           where:
             i.token == ^hash(decoded_token) and is_nil(i.accepted_at) and
               i.expires_at > ^now
         )}

      :error ->
        :error
    end
  end

  def verify_token_query(_token), do: :error

  def pending_query do
    now = DateTime.utc_now(:second)
    from(i in __MODULE__, where: is_nil(i.accepted_at) and i.expires_at > ^now)
  end

  defp hash(token), do: :crypto.hash(@hash_algorithm, token)
end
