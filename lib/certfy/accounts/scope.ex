defmodule Certfy.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Certfy.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use in authorization checks,
  or to ensure specific code paths can only be accessed for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Certfy.Accounts.User

  import Ecto.Query, only: [where: 3]

  defstruct user: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Returns true when the scoped user is an admin.
  """
  def admin?(%__MODULE__{user: %User{role: :ADMIN}}), do: true
  def admin?(_scope), do: false

  @doc """
  Restricts a query to the records owned by the scoped user.

  Admins see every record, so no restriction is applied.
  """
  def owned(query, %__MODULE__{} = scope) do
    case owner_id(scope) do
      nil -> query
      id -> where(query, [first], first.user_id == ^id)
    end
  end

  @doc """
  Returns the id used to restrict owned records, or nil when the scope has
  access to the records of every user.
  """
  def owner_id(%__MODULE__{user: %User{role: :ADMIN}}), do: nil
  def owner_id(%__MODULE__{user: %User{id: id}}), do: id

  @doc """
  Returns true when the scoped user owns the given record.
  """
  def owner?(%__MODULE__{} = scope, %{user_id: user_id}) do
    admin?(scope) or user_id == scope.user.id
  end
end
