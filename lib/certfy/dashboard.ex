defmodule Certfy.Dashboard do
  @moduledoc """
  Scoped summaries for the home dashboard.

  Admins see aggregates for every record, while regular users only see their
  own data.
  """

  import Ecto.Query, warn: false

  alias Certfy.Repo
  alias Certfy.Accounts.Scope
  alias Certfy.Events.{Batch, Event, Participant}
  alias Certfy.Certificates.Certificate

  @doc """
  Returns the counters shown on the dashboard for the given scope.
  """
  def summary(%Scope{} = scope) do
    %{
      events: count_events(scope),
      batches: count_batches(scope),
      participants: count_participants(scope),
      certificates: certificate_counts(scope),
      attention: attention_counts(scope)
    }
  end

  @doc """
  Returns the most recently updated events with batch and participant counts.
  """
  def recent_events(%Scope{} = scope, limit \\ 5) do
    batch_counts =
      from(b in Batch,
        group_by: b.event_id,
        select: %{event_id: b.event_id, total: count(b.id)}
      )
      |> Scope.owned(scope)

    participant_counts =
      from(p in Participant,
        join: b in Batch,
        on: p.batch_id == b.id,
        group_by: b.event_id,
        select: %{event_id: b.event_id, total: count(p.id)}
      )
      |> Scope.owned(scope)

    from(e in Event,
      order_by: [desc: e.updated_at, desc: e.id],
      limit: ^limit,
      left_join: bc in subquery(batch_counts),
      on: bc.event_id == e.id,
      left_join: pc in subquery(participant_counts),
      on: pc.event_id == e.id,
      select: %{
        id: e.id,
        name: e.name,
        template_path: e.template_path,
        template_report: e.template_report,
        updated_at: e.updated_at,
        batch_count: coalesce(bc.total, 0),
        participant_count: coalesce(pc.total, 0)
      }
    )
    |> Scope.owned(scope)
    |> Repo.all()
  end

  defp count_events(scope) do
    from(e in Event)
    |> Scope.owned(scope)
    |> Repo.aggregate(:count, :id)
  end

  defp count_batches(scope) do
    from(b in Batch)
    |> Scope.owned(scope)
    |> Repo.aggregate(:count, :id)
  end

  defp count_participants(scope) do
    from(p in Participant)
    |> Scope.owned(scope)
    |> Repo.aggregate(:count, :id)
  end

  defp certificate_counts(scope) do
    status_counts =
      from(c in Certificate,
        group_by: c.status,
        select: {c.status, count(c.id)}
      )
      |> Scope.owned(scope)
      |> Repo.all()
      |> Map.new()

    sent =
      from(c in Certificate,
        where: not is_nil(c.emailed_at),
        select: count(c.id)
      )
      |> Scope.owned(scope)
      |> Repo.one()

    %{
      generated: Map.get(status_counts, :ready, 0),
      pending: Map.get(status_counts, :pending, 0) + Map.get(status_counts, :processing, 0),
      failed: Map.get(status_counts, :failed, 0),
      sent: sent
    }
  end

  defp attention_counts(scope) do
    %{
      events_without_template:
        from(e in Event, where: is_nil(e.template_path))
        |> Scope.owned(scope)
        |> Repo.aggregate(:count, :id),
      batches_without_participants: count_batches_without_participants(scope),
      participants_without_email:
        from(p in Participant, where: is_nil(p.email) or p.email == "")
        |> Scope.owned(scope)
        |> Repo.aggregate(:count, :id)
    }
  end

  defp count_batches_without_participants(scope) do
    from(b in Batch,
      left_join: p in Participant,
      on: p.batch_id == b.id,
      group_by: b.id,
      having: count(p.id) == 0,
      select: b.id
    )
    |> Scope.owned(scope)
    |> Repo.all()
    |> length()
  end
end
