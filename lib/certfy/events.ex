defmodule Certfy.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Certfy.Repo
  alias Certfy.Storage

  alias Certfy.Events.{Batch, Event, Participant}
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
  Returns a paginated and filtered list of events.

  Supported options: `"q"`, `"template"` (`"yes"`/`"no"`), `"sort"`
  (`"updated"`/`"name"`) and `"page"`.
  """
  def list_events_page(%Scope{} = scope, opts \\ %{}) do
    page = parse_page(opts["page"])
    per_page = 25

    query =
      from(e in Event, where: e.user_id == ^scope.user.id)
      |> filter_event_query(opts)
      |> order_events(opts["sort"])

    total = Repo.aggregate(query, :count, :id)

    items =
      Repo.all(
        from e in query,
          limit: ^per_page,
          offset: ^((page - 1) * per_page)
      )

    page_result(items, total, page, per_page)
  end

  @doc """
  Counts the batches of an event.
  """
  def count_batches(%Scope{} = scope, %Event{} = event) do
    Repo.aggregate(
      from(b in Batch, where: b.event_id == ^event.id and b.user_id == ^scope.user.id),
      :count,
      :id
    )
  end

  @doc """
  Counts the participants of a batch.
  """
  def count_participants(%Scope{} = scope, %Batch{} = batch) do
    Repo.aggregate(
      from(p in Participant, where: p.batch_id == ^batch.id and p.user_id == ^scope.user.id),
      :count,
      :id
    )
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
  Returns all batches of the user with their event preloaded.
  """
  def list_batches_with_events(%Scope{} = scope) do
    Repo.all_by(Batch, user_id: scope.user.id)
    |> Repo.preload(:event)
  end

  @doc """
  Returns the list of batches for the given event.
  """
  def list_batches(%Scope{} = scope, %Event{} = event) do
    Repo.all_by(Batch, user_id: scope.user.id, event_id: event.id)
  end

  @doc """
  Returns a paginated and filtered list of all batches of the user.

  Supported options: `"q"`, `"event_id"` and `"page"`.
  """
  def list_batches_page(%Scope{} = scope, opts \\ %{}) do
    page = parse_page(opts["page"])
    per_page = 25

    query =
      from(b in Batch,
        join: e in assoc(b, :event),
        where: b.user_id == ^scope.user.id
      )
      |> filter_batch_query(opts)
      |> order_by([b], desc: b.updated_at)

    total = Repo.aggregate(query, :count, :id)

    items =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()
      |> Repo.preload(:event)
      |> attach_participant_counts()

    page_result(items, total, page, per_page)
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
  Gets a batch with its event preloaded.
  """
  def get_batch_with_event!(%Scope{} = scope, id) do
    scope
    |> get_batch!(id)
    |> Repo.preload(:event)
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
  Returns a paginated and filtered list of participants for a batch.

  Supported options: `"q"`, `"email"` (`"with"`/`"without"`) and `"page"`.
  """
  def list_participants_page(%Scope{} = scope, %Batch{} = batch, opts \\ %{}) do
    page = parse_page(opts["page"])
    per_page = 25

    query =
      from(p in Participant,
        where: p.batch_id == ^batch.id and p.user_id == ^scope.user.id
      )
      |> filter_participant_query(opts)
      |> order_by([p], asc: p.name)

    total = Repo.aggregate(query, :count, :id)

    items =
      Repo.all(
        from p in query,
          limit: ^per_page,
          offset: ^((page - 1) * per_page)
      )

    page_result(items, total, page, per_page)
  end

  @doc """
  Returns a paginated and filtered list of all participants of the user.

  Supported options: `"q"`, `"event_id"`, `"batch_id"` and `"page"`.
  """
  def list_participants_page_all(%Scope{} = scope, opts \\ %{}) do
    page = parse_page(opts["page"])
    per_page = 25

    query =
      from(p in Participant,
        join: b in assoc(p, :batch),
        join: e in assoc(b, :event),
        where: p.user_id == ^scope.user.id
      )
      |> filter_global_participant_query(opts)
      |> order_by([p], asc: p.name)

    total = Repo.aggregate(query, :count, :id)

    items =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()
      |> Repo.preload(batch: :event)

    page_result(items, total, page, per_page)
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
  Gets a participant with its batch and event preloaded.
  """
  def get_participant_with_context!(%Scope{} = scope, id) do
    scope
    |> get_participant!(id)
    |> Repo.preload(batch: :event)
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

  defp filter_event_query(query, opts) do
    query =
      case normalize_term(opts["q"]) do
        nil -> query
        term -> where(query, [e], ilike(e.name, ^"%#{term}%"))
      end

    case opts["template"] do
      "yes" -> where(query, [e], not is_nil(e.template_path))
      "no" -> where(query, [e], is_nil(e.template_path))
      _ -> query
    end
  end

  defp filter_participant_query(query, opts) do
    query =
      case normalize_term(opts["q"]) do
        nil ->
          query

        term ->
          where(
            query,
            [p],
            ilike(p.name, ^"%#{term}%") or ilike(p.email, ^"%#{term}%")
          )
      end

    case opts["email"] do
      "with" -> where(query, [p], not is_nil(p.email) and p.email != "")
      "without" -> where(query, [p], is_nil(p.email) or p.email == "")
      _ -> query
    end
  end

  defp filter_batch_query(query, opts) do
    query =
      case normalize_term(opts["q"]) do
        nil ->
          query

        term ->
          where(
            query,
            [b, e],
            ilike(b.name, ^"%#{term}%") or ilike(e.name, ^"%#{term}%")
          )
      end

    case normalize_term(opts["event_id"]) do
      nil -> query
      event_id -> where(query, [b], b.event_id == ^event_id)
    end
  end

  defp filter_global_participant_query(query, opts) do
    query =
      case normalize_term(opts["q"]) do
        nil ->
          query

        term ->
          where(
            query,
            [p],
            ilike(p.name, ^"%#{term}%") or ilike(p.email, ^"%#{term}%")
          )
      end

    query =
      case normalize_term(opts["event_id"]) do
        nil -> query
        event_id -> where(query, [p, b, e], e.id == ^event_id)
      end

    case normalize_term(opts["batch_id"]) do
      nil -> query
      batch_id -> where(query, [p], p.batch_id == ^batch_id)
    end
  end

  defp attach_participant_counts([]), do: []

  defp attach_participant_counts(batches) do
    ids = Enum.map(batches, & &1.id)

    counts =
      Repo.all(
        from p in Participant,
          where: p.batch_id in ^ids,
          group_by: p.batch_id,
          select: {p.batch_id, count(p.id)}
      )
      |> Map.new()

    Enum.map(batches, &%{&1 | participants_count: Map.get(counts, &1.id, 0)})
  end

  defp order_events(query, "name"), do: order_by(query, [e], asc: e.name)
  defp order_events(query, _sort), do: order_by(query, [e], desc: e.updated_at)

  defp normalize_term(nil), do: nil
  defp normalize_term(term) when is_integer(term), do: term

  defp normalize_term(term) when is_binary(term) do
    case String.trim(term) do
      "" -> nil
      term -> term
    end
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp parse_page(_page), do: 1

  defp page_result(items, total, page, per_page) do
    %{
      items: items,
      total: total,
      page: page,
      per_page: per_page,
      pages: max(ceil(total / per_page), 1)
    }
  end
end
