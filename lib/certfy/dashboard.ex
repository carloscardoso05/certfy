defmodule Certfy.Dashboard do
  @moduledoc """
  Scoped summaries for the home dashboard.
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
    user_id = scope.user.id

    %{
      events: count_events(user_id),
      batches: count_batches(user_id),
      participants: count_participants(user_id),
      certificates: certificate_counts(user_id),
      attention: attention_counts(user_id)
    }
  end

  @doc """
  Returns the most recently updated events with batch and participant counts.
  """
  def recent_events(%Scope{} = scope, limit \\ 5) do
    user_id = scope.user.id

    batch_counts =
      from(b in Batch,
        where: b.user_id == ^user_id,
        group_by: b.event_id,
        select: %{event_id: b.event_id, total: count(b.id)}
      )

    participant_counts =
      from(p in Participant,
        join: b in Batch,
        on: p.batch_id == b.id,
        where: p.user_id == ^user_id,
        group_by: b.event_id,
        select: %{event_id: b.event_id, total: count(p.id)}
      )

    from(e in Event,
      where: e.user_id == ^user_id,
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
    |> Repo.all()
  end

  defp count_events(user_id) do
    Repo.aggregate(from(e in Event, where: e.user_id == ^user_id), :count, :id)
  end

  defp count_batches(user_id) do
    Repo.aggregate(from(b in Batch, where: b.user_id == ^user_id), :count, :id)
  end

  defp count_participants(user_id) do
    Repo.aggregate(from(p in Participant, where: p.user_id == ^user_id), :count, :id)
  end

  defp certificate_counts(user_id) do
    status_counts =
      from(c in Certificate,
        where: c.user_id == ^user_id,
        group_by: c.status,
        select: {c.status, count(c.id)}
      )
      |> Repo.all()
      |> Map.new()

    sent =
      from(c in Certificate,
        where: c.user_id == ^user_id and not is_nil(c.emailed_at),
        select: count(c.id)
      )
      |> Repo.one()

    %{
      generated: Map.get(status_counts, :ready, 0),
      pending: Map.get(status_counts, :pending, 0) + Map.get(status_counts, :processing, 0),
      failed: Map.get(status_counts, :failed, 0),
      sent: sent
    }
  end

  defp attention_counts(user_id) do
    %{
      events_without_template:
        Repo.aggregate(
          from(e in Event, where: e.user_id == ^user_id and is_nil(e.template_path)),
          :count,
          :id
        ),
      batches_without_participants: count_batches_without_participants(user_id),
      participants_without_email:
        Repo.aggregate(
          from(p in Participant,
            where: p.user_id == ^user_id,
            where: is_nil(p.email) or p.email == ""
          ),
          :count,
          :id
        )
    }
  end

  defp count_batches_without_participants(user_id) do
    from(b in Batch,
      where: b.user_id == ^user_id,
      left_join: p in Participant,
      on: p.batch_id == b.id,
      group_by: b.id,
      having: count(p.id) == 0,
      select: b.id
    )
    |> Repo.all()
    |> length()
  end
end
