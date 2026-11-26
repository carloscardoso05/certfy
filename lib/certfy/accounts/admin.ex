defmodule Certfy.Accounts.Admin do
  @moduledoc """
  Admin-only user management: invitations, deactivation and roles.
  """

  import Ecto.Query, warn: false

  alias Certfy.Repo
  alias Certfy.Accounts
  alias Certfy.Accounts.{Invitation, Scope, User, UserNotifier}

  @doc "Lists every user, including deactivated ones."
  def list_users(scope, opts \\ %{}) do
    authorize_admin!(scope)

    query = from u in User, order_by: [asc: u.name]

    query =
      case normalize_term(opts["q"]) do
        nil ->
          query

        term ->
          where(
            query,
            [u],
            ilike(u.name, ^"%#{term}%") or ilike(u.email, ^"%#{term}%")
          )
      end

    query =
      case opts["role"] do
        "ADMIN" -> where(query, [u], u.role == :ADMIN)
        "USER" -> where(query, [u], u.role == :USER)
        _ -> query
      end

    case opts["status"] do
      "active" -> Repo.all(where(query, [u], is_nil(u.deactivated_at)))
      "deactivated" -> Repo.all(where(query, [u], not is_nil(u.deactivated_at)))
      _ -> Repo.all(query)
    end
  end

  @doc "Gets a user by id for admin actions."
  def get_user(scope, id) do
    authorize_admin!(scope)
    Repo.get(User, id)
  end

  @doc "Lists invitations that were not accepted yet and are still valid."
  def list_pending_invitations(scope, opts \\ %{}) do
    authorize_admin!(scope)

    query =
      from i in Invitation.pending_query(),
        order_by: [desc: i.inserted_at],
        preload: [:invited_by]

    query =
      case normalize_term(opts["q"]) do
        nil -> query
        term -> where(query, [i], ilike(i.email, ^"%#{term}%"))
      end

    Repo.all(query)
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

  @doc "Gets an invitation by id for admin actions."
  def get_invitation(scope, id) do
    authorize_admin!(scope)
    Repo.get(Invitation, id)
  end

  @doc "Resends a pending invitation, replacing the previous token."
  def resend_invitation(scope, %Invitation{} = invitation, invited_url_fun)
      when is_function(invited_url_fun, 1) do
    authorize_admin!(scope)

    if invitation.accepted_at ||
         DateTime.compare(invitation.expires_at, DateTime.utc_now(:second)) != :gt do
      {:error, :invalid_invitation}
    else
      {new_invitation, token} = Invitation.build(invitation.email, scope.user.id)

      Repo.transact(fn ->
        Repo.delete!(invitation)
        {:ok, new_invitation} = Repo.insert(new_invitation)

        UserNotifier.deliver_invitation_instructions(
          new_invitation,
          invited_url_fun.(token),
          scope.user
        )

        {:ok, new_invitation}
      end)
    end
  end

  @doc "Revokes a pending invitation."
  def revoke_invitation(scope, %Invitation{} = invitation) do
    authorize_admin!(scope)
    Repo.delete(invitation)
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

  defp normalize_term(nil), do: nil

  defp normalize_term(term) when is_binary(term) do
    case String.trim(term) do
      "" -> nil
      term -> term
    end
  end
end
