defmodule Certfy.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Certfy.Repo
  alias Certfy.Storage

  alias Certfy.Events.Event
  alias Certfy.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any event changes.

  The broadcasted messages match the pattern:

    * {:created, %Event{}}
    * {:updated, %Event{}}
    * {:deleted, %Event{}}

  """
  def subscribe_events(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Certfy.PubSub, "user:#{key}:events")
  end

  defp broadcast_event(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Certfy.PubSub, "user:#{key}:events", message)
  end

  @doc """
  Returns the list of events.

  ## Examples

      iex> list_events(scope)
      [%Event{}, ...]

  """
  def list_events(%Scope{} = scope) do
    Repo.all_by(Event, user_id: scope.user.id)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(scope, 123)
      %Event{}

      iex> get_event!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(%Scope{} = scope, id) do
    Repo.get_by!(Event, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(scope, %{field: value})
      {:ok, %Event{}}

      iex> create_event(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(%Scope{} = scope, attrs, opts \\ []) do
    with {:ok, event = %Event{}} <-
           %Event{}
           |> Event.changeset(attrs, scope, opts)
           |> Repo.insert() do
      broadcast_event(scope, {:created, event})
      {:ok, event}
    end
  end

  @doc """
  Updates a event.

  ## Examples

      iex> update_event(scope, event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(scope, event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Scope{} = scope, %Event{} = event, attrs, opts \\ []) do
    true = event.user_id == scope.user.id
    old_template_path = event.template_path

    with {:ok, event = %Event{}} <-
           event
           |> Event.changeset(attrs, scope, opts)
           |> Repo.update() do
      maybe_delete_replaced_template(old_template_path, event.template_path)
      broadcast_event(scope, {:updated, event})
      {:ok, event}
    end
  end

  @doc """
  Removes the template from an event and deletes the stored object.
  """
  def remove_event_template(%Scope{} = scope, %Event{} = event) do
    true = event.user_id == scope.user.id

    with :ok <- delete_template_object(event.template_path),
         {:ok, event = %Event{}} <-
           event
           |> Ecto.Changeset.change(template_path: nil)
           |> Repo.update() do
      broadcast_event(scope, {:updated, event})
      {:ok, event}
    end
  end

  defp maybe_delete_replaced_template(nil, _new_template_path), do: :ok
  defp maybe_delete_replaced_template(path, path), do: :ok

  defp maybe_delete_replaced_template(old_template_path, _new_template_path) do
    delete_template_object(old_template_path)
    :ok
  end

  defp delete_template_object(nil), do: :ok

  defp delete_template_object(template_path) do
    case Storage.delete_template(template_path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Could not delete template #{template_path}: #{inspect(reason)}")

        {:error, reason}
    end
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(scope, event)
      {:ok, %Event{}}

      iex> delete_event(scope, event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Scope{} = scope, %Event{} = event) do
    true = event.user_id == scope.user.id

    with {:ok, event = %Event{}} <-
           Repo.delete(event) do
      broadcast_event(scope, {:deleted, event})
      {:ok, event}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(scope, event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Scope{} = scope, %Event{} = event, attrs \\ %{}) do
    true = event.user_id == scope.user.id

    Event.changeset(event, attrs, scope)
  end

  alias Certfy.Events.Batch
  alias Certfy.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any batch changes.

  The broadcasted messages match the pattern:

    * {:created, %Batch{}}
    * {:updated, %Batch{}}
    * {:deleted, %Batch{}}

  """
  def subscribe_batches(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Certfy.PubSub, "user:#{key}:batches")
  end

  defp broadcast_batch(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Certfy.PubSub, "user:#{key}:batches", message)
  end

  @doc """
  Returns the list of batches.

  ## Examples

      iex> list_batches(scope)
      [%Batch{}, ...]

  """
  def list_batches(%Scope{} = scope) do
    Repo.all_by(Batch, user_id: scope.user.id)
  end

  @doc """
  Returns the list of batches for the given event.
  """
  def list_batches(%Scope{} = scope, %Event{} = event) do
    Repo.all_by(Batch, user_id: scope.user.id, event_id: event.id)
  end

  @doc """
  Gets a single batch.

  Raises `Ecto.NoResultsError` if the Batch does not exist.

  ## Examples

      iex> get_batch!(scope, 123)
      %Batch{}

      iex> get_batch!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_batch!(%Scope{} = scope, id) do
    Repo.get_by!(Batch, id: id, user_id: scope.user.id)
  end

  @doc """
  Gets a single batch for the given event.

  Raises `Ecto.NoResultsError` if the Batch does not exist.
  """
  def get_batch!(%Scope{} = scope, %Event{} = event, id) do
    Repo.get_by!(Batch, id: id, user_id: scope.user.id, event_id: event.id)
  end

  @doc """
  Creates a batch.

  ## Examples

      iex> create_batch(scope, %{field: value})
      {:ok, %Batch{}}

      iex> create_batch(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_batch(%Scope{} = scope, %Event{} = event, attrs) do
    true = event.user_id === scope.user.id

    with {:ok, batch = %Batch{}} <-
           event
           |> Ecto.build_assoc(:batches)
           |> Batch.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_batch(scope, {:created, batch})
      {:ok, batch}
    end
  end

  @doc """
  Updates a batch.

  ## Examples

      iex> update_batch(scope, batch, %{field: new_value})
      {:ok, %Batch{}}

      iex> update_batch(scope, batch, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_batch(%Scope{} = scope, %Batch{} = batch, attrs) do
    true = batch.user_id == scope.user.id

    with {:ok, batch = %Batch{}} <-
           batch
           |> Batch.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_batch(scope, {:updated, batch})
      {:ok, batch}
    end
  end

  @doc """
  Deletes a batch.

  ## Examples

      iex> delete_batch(scope, batch)
      {:ok, %Batch{}}

      iex> delete_batch(scope, batch)
      {:error, %Ecto.Changeset{}}

  """
  def delete_batch(%Scope{} = scope, %Batch{} = batch) do
    true = batch.user_id == scope.user.id

    with {:ok, batch = %Batch{}} <-
           Repo.delete(batch) do
      broadcast_batch(scope, {:deleted, batch})
      {:ok, batch}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking batch changes.

  ## Examples

      iex> change_batch(scope, batch)
      %Ecto.Changeset{data: %Batch{}}

  """
  def change_batch(%Scope{} = scope, %Batch{} = batch, attrs \\ %{}) do
    true = batch.user_id == scope.user.id

    Batch.changeset(batch, attrs, scope)
  end

  alias Certfy.Events.Participant
  alias Certfy.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any participant changes.

  The broadcasted messages match the pattern:

    * {:created, %Participant{}}
    * {:updated, %Participant{}}
    * {:deleted, %Participant{}}

  """
  def subscribe_participants(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Certfy.PubSub, "user:#{key}:participants")
  end

  defp broadcast_participant(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Certfy.PubSub, "user:#{key}:participants", message)
  end

  @doc """
  Returns the list of participants.

  ## Examples

      iex> list_participants(scope)
      [%Participant{}, ...]

  """
  def list_participants(%Scope{} = scope) do
    Repo.all_by(Participant, user_id: scope.user.id)
  end

  @doc """
  Returns the list of participants for the given batch.
  """
  def list_participants(%Scope{} = scope, %Batch{} = batch) do
    Repo.all_by(Participant, user_id: scope.user.id, batch_id: batch.id)
  end

  @doc """
  Gets a single participant.

  Raises `Ecto.NoResultsError` if the Participant does not exist.

  ## Examples

      iex> get_participant!(scope, 123)
      %Participant{}

      iex> get_participant!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_participant!(%Scope{} = scope, id) do
    Repo.get_by!(Participant, id: id, user_id: scope.user.id)
  end

  @doc """
  Gets a single participant for the given batch.

  Raises `Ecto.NoResultsError` if the Participant does not exist.
  """
  def get_participant!(%Scope{} = scope, %Batch{} = batch, id) do
    Repo.get_by!(Participant, id: id, user_id: scope.user.id, batch_id: batch.id)
  end

  @doc """
  Creates a participant.

  ## Examples

      iex> create_participant(scope, %{field: value})
      {:ok, %Participant{}}

      iex> create_participant(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_participant(%Scope{} = scope, %Batch{} = batch, attrs) do
    true = batch.user_id === scope.user.id

    with {:ok, participant = %Participant{}} <-
           batch
           |> Ecto.build_assoc(:participants)
           |> Participant.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_participant(scope, {:created, participant})
      {:ok, participant}
    end
  end

  @doc """
  Updates a participant.

  ## Examples

      iex> update_participant(scope, participant, %{field: new_value})
      {:ok, %Participant{}}

      iex> update_participant(scope, participant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_participant(%Scope{} = scope, %Participant{} = participant, attrs) do
    true = participant.user_id == scope.user.id

    with {:ok, participant = %Participant{}} <-
           participant
           |> Participant.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_participant(scope, {:updated, participant})
      {:ok, participant}
    end
  end

  @doc """
  Deletes a participant.

  ## Examples

      iex> delete_participant(scope, participant)
      {:ok, %Participant{}}

      iex> delete_participant(scope, participant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_participant(%Scope{} = scope, %Participant{} = participant) do
    true = participant.user_id == scope.user.id

    with {:ok, participant = %Participant{}} <-
           Repo.delete(participant) do
      broadcast_participant(scope, {:deleted, participant})
      {:ok, participant}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking participant changes.

  ## Examples

      iex> change_participant(scope, participant)
      %Ecto.Changeset{data: %Participant{}}

  """
  def change_participant(%Scope{} = scope, %Participant{} = participant, attrs \\ %{}) do
    true = participant.user_id == scope.user.id

    Participant.changeset(participant, attrs, scope)
  end
end
