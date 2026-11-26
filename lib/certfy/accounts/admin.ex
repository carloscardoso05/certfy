defmodule Certfy.Accounts.Admin do
  @moduledoc """
  Admin-only user management: invitations, deactivation and roles.
  """

  import Ecto.Query, warn: false

  alias Certfy.Repo
  alias Certfy.Accounts
  alias Certfy.Accounts.{Invitation, Scope, User, UserNotifier}

  @doc "Lists every user, including deactivated ones."
  def list_users(scope) do
    authorize_admin!(scope)

    Repo.all(from u in User, order_by: [asc: u.name])
  end

  @doc "Gets a user by id for admin actions."
  def get_user(scope, id) do
    authorize_admin!(scope)
    Repo.get(User, id)
  end

  @doc "Lists invitations that were not accepted yet and are still valid."
  def list_pending_invitations(scope) do
    authorize_admin!(scope)

    Repo.all(
      from i in Invitation.pending_query(),
        order_by: [desc: i.inserted_at],
        preload: [:invited_by]
    )
  end

  @doc """
  Invites an email to create an account.

  Returns `{:ok, invitation}`, `{:error, :already_registered}` or an invalid
  changeset when the email is malformed.
  """
  def invite_user(scope, email, invited_url_fun)
      when is_function(invited_url_fun, 1) do
    authorize_admin!(scope)
    email = String.trim(email)

    cond do
      Accounts.get_user_by_email(email) ->
        {:error, :already_registered}

      true ->
        changeset = Invitation.changeset(%Invitation{}, %{email: email})

        if changeset.valid? do
          {invitation, token} = Invitation.build(email, scope.user.id)

          Repo.transact(fn ->
            Repo.delete_all(
              from i in Invitation,
                where: i.email == ^email and is_nil(i.accepted_at)
            )

            {:ok, invitation} = Repo.insert(invitation)

            UserNotifier.deliver_invitation_instructions(
              invitation,
              invited_url_fun.(token),
              scope.user
            )

            {:ok, invitation}
          end)
        else
          {:error, changeset}
        end
    end
  end

  @doc "Deactivates a user and expires every token of theirs."
  def deactivate_user(scope, %User{} = user) do
    authorize_admin!(scope)

    if user.id == scope.user.id do
      {:error, :cannot_modify_self}
    else
      user
      |> User.deactivation_changeset(DateTime.utc_now(:second))
      |> Accounts.update_user_and_delete_all_tokens()
    end
  end

  @doc "Reactivates a user."
  def reactivate_user(scope, %User{} = user) do
    authorize_admin!(scope)

    user
    |> User.deactivation_changeset(nil)
    |> Repo.update()
  end

  @doc "Changes a user role. Admins cannot demote themselves."
  def change_role(scope, %User{} = user, role) do
    authorize_admin!(scope)

    if user.id == scope.user.id and role != :ADMIN do
      {:error, :cannot_modify_self}
    else
      user
      |> User.role_changeset(role)
      |> Repo.update()
    end
  end

  defp authorize_admin!(%Scope{user: %User{role: :ADMIN}}), do: :ok

  defp authorize_admin!(_scope) do
    raise ArgumentError, "admin access required"
  end
end
