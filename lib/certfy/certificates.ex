defmodule Certfy.Certificates do
  @moduledoc """
  Certificate templates, issued certificates and bulk generation/sending.
  """

  import Ecto.Query, warn: false

  alias Certfy.Repo
  alias Certfy.Accounts.Scope
  alias Certfy.Events.Participant
  alias Certfy.Certificates.{Certificate, QR}
  alias Certfy.Workers.{GenerateCertificate, SendCertificateEmail}

  ## Certificates

  def subscribe_certificates(%Scope{} = scope) do
    Phoenix.PubSub.subscribe(Certfy.PubSub, "user:#{scope.user.id}:certificates")
  end

  def get_certificate!(%Scope{} = scope, id) do
    Repo.get_by!(Certificate, id: id, user_id: scope.user.id)
  end

  def get_certificate(id) do
    Repo.get(Certificate, id)
  end

  def get_certificate_with_context(id) do
    Repo.one(
      from(c in Certificate,
        where: c.id == ^id,
        preload: [:batch, :event, participant: [batch: :event]]
      )
    )
  end

  def get_certificate_for_participant(%Scope{} = scope, participant_id) do
    Repo.get_by(Certificate, participant_id: participant_id, user_id: scope.user.id)
  end

  def get_certificate_for_download(%Scope{} = scope, id) do
    scope
    |> get_certificate!(id)
    |> Repo.preload([:participant, :event, :batch])
  end

  def get_certificate_by_code(code) when is_binary(code) do
    code = code |> String.trim() |> String.upcase()

    Repo.one(
      from(c in Certificate,
        where: c.code == ^code,
        preload: [:participant, :batch, :event]
      )
    )
  end

  @doc """
  Creates and queues generation for the given participants.

  Ready and failed certificates are regenerated (and marked as not sent).
  Certificates already pending/processing are skipped.
  """
  def prepare_for_participants(%Scope{} = scope, participant_ids) when is_list(participant_ids) do
    participants = load_participants(scope, participant_ids)
    certificates = certificates_by_participant(scope, Enum.map(participants, & &1.id))

    {to_queue, stats} =
      Enum.reduce(participants, {[], %{no_template: 0, invalid_template: 0, in_progress: 0}}, fn
        participant, {to_queue, stats} ->
          event = participant.batch.event

          cond do
            is_nil(event.template_path) ->
              {to_queue, %{stats | no_template: stats.no_template + 1}}

            malformed_template?(event) ->
              {to_queue, %{stats | invalid_template: stats.invalid_template + 1}}

            true ->
              {new?, certificate} =
                case Map.get(certificates, participant.id) do
                  nil -> {true, create_certificate!(participant, event)}
                  certificate -> {false, certificate}
                end

              if not new? and certificate.status in [:pending, :processing] do
                {to_queue, %{stats | in_progress: stats.in_progress + 1}}
              else
                {:ok, certificate} =
                  update_certificate(certificate, %{
                    status: :pending,
                    error: nil,
                    email_status: :pending,
                    emailed_at: nil
                  })

                {[certificate | to_queue], stats}
              end
          end
      end)

    queued = enqueue_generation(to_queue)

    %{
      queued: queued,
      selected: length(participant_ids),
      no_template: stats.no_template,
      invalid_template: stats.invalid_template,
      in_progress: stats.in_progress
    }
  end

  def malformed_template?(%Certfy.Events.Event{} = event) do
    malformed = get_in(event.template_report || %{}, ["malformed"]) || []
    malformed != []
  end

  @doc """
  Queues certificate e-mails for the given participants.

  Sends only generated certificates, but includes ones already sent (resend).
  """
  def send_emails(%Scope{} = scope, participant_ids) when is_list(participant_ids) do
    certificates =
      from(c in Certificate,
        where: c.user_id == ^scope.user.id and c.participant_id in ^participant_ids,
        preload: [:participant]
      )
      |> Repo.all()

    {to_queue, stats} =
      Enum.reduce(certificates, {[], %{no_email: 0, not_ready: 0, in_progress: 0}}, fn
        certificate, {to_queue, stats} ->
          cond do
            is_nil(certificate.participant.email) or certificate.participant.email == "" ->
              {to_queue, %{stats | no_email: stats.no_email + 1}}

            certificate.status in [:pending, :processing] ->
              {to_queue, %{stats | in_progress: stats.in_progress + 1}}

            certificate.status != :ready or is_nil(certificate.pdf_path) ->
              {to_queue, %{stats | not_ready: stats.not_ready + 1}}

            true ->
              {:ok, certificate} =
                update_certificate(certificate, %{email_status: :pending, email_error: nil})

              {[certificate | to_queue], stats}
          end
      end)

    queued = enqueue_email(to_queue)

    %{
      queued: queued,
      selected: length(participant_ids),
      no_email: stats.no_email,
      not_ready: stats.not_ready,
      in_progress: stats.in_progress,
      missing: length(participant_ids) - length(certificates)
    }
  end

  def prepare_for_batch(%Scope{} = scope, batch_id) do
    ids =
      Repo.all(
        from(p in Participant,
          where: p.user_id == ^scope.user.id and p.batch_id == ^batch_id,
          select: p.id
        )
      )

    prepare_for_participants(scope, ids)
  end

  def send_emails_for_batch(%Scope{} = scope, batch_id) do
    ids =
      Repo.all(
        from(p in Participant,
          where: p.user_id == ^scope.user.id and p.batch_id == ^batch_id,
          select: p.id
        )
      )

    send_emails(scope, ids)
  end

  def update_certificate(%Certificate{} = certificate, attrs) do
    certificate
    |> Certificate.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, certificate} ->
        broadcast(certificate)
        {:ok, certificate}

      other ->
        other
    end
  end

  def mark_processing(%Certificate{} = certificate) do
    update_certificate(certificate, %{status: :processing, error: nil})
  end

  def mark_ready(%Certificate{} = certificate, attrs) do
    update_certificate(certificate, attrs)
  end

  def mark_failed(%Certificate{} = certificate, error) do
    update_certificate(certificate, %{status: :failed, error: to_string(error)})
  end

  def mark_email_sent(%Certificate{} = certificate) do
    update_certificate(certificate, %{
      email_status: :sent,
      emailed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      email_error: nil
    })
  end

  def mark_email_failed(%Certificate{} = certificate, error) do
    update_certificate(certificate, %{
      email_status: :failed,
      email_error: to_string(error)
    })
  end

  def mark_email_skipped(%Certificate{} = certificate) do
    update_certificate(certificate, %{email_status: :skipped})
  end

  defp create_certificate!(participant, event, attempts \\ 0) do
    certificate = %Certificate{
      user_id: participant.user_id,
      event_id: event.id,
      batch_id: participant.batch_id,
      participant_id: participant.id,
      code: QR.code(),
      status: :pending,
      email_status: :pending,
      version: 0,
      snapshot: %{},
      warnings: []
    }

    case Repo.insert(certificate) do
      {:ok, certificate} ->
        certificate

      {:error, changeset} ->
        if attempts < 5 and Keyword.has_key?(changeset.errors, :code) do
          create_certificate!(participant, event, attempts + 1)
        else
          raise Ecto.InvalidChangesetError, action: :insert, changeset: changeset
        end
    end
  end

  defp load_participants(scope, ids) do
    from(p in Participant,
      join: b in assoc(p, :batch),
      join: e in assoc(b, :event),
      where: p.user_id == ^scope.user.id and p.id in ^ids,
      preload: [batch: :event]
    )
    |> Repo.all()
  end

  defp certificates_by_participant(scope, participant_ids) do
    from(c in Certificate,
      where: c.user_id == ^scope.user.id and c.participant_id in ^participant_ids
    )
    |> Repo.all()
    |> Map.new(&{&1.participant_id, &1})
  end

  defp enqueue_generation(certificates) do
    certificates
    |> Enum.map(&GenerateCertificate.new(%{certificate_id: &1.id, version: &1.version}))
    |> Oban.insert_all()
    |> length()
  end

  defp enqueue_email(certificates) do
    certificates
    |> Enum.map(&SendCertificateEmail.new(%{certificate_id: &1.id, version: &1.version}))
    |> Oban.insert_all()
    |> length()
  end

  defp broadcast(%Certificate{} = certificate) do
    Phoenix.PubSub.broadcast(
      Certfy.PubSub,
      "user:#{certificate.user_id}:certificates",
      {:certificate_updated, certificate}
    )
  end

  ## Selection helpers

  def participant_ids(%Scope{} = scope, filters, selection) do
    scope
    |> participants_query(filters)
    |> apply_selection(selection)
    |> select([p], p.id)
    |> distinct(true)
    |> Repo.all()
  end

  def selection_counts(%Scope{} = scope, filters) do
    base = participants_query(scope, filters)

    %{
      all: count_selection(base, :all),
      not_generated: count_selection(base, :not_generated),
      not_sent: count_selection(base, :not_sent),
      error: count_selection(base, :error),
      no_email: count_selection(base, :no_email)
    }
  end

  def selection_summary(%Scope{} = scope, participant_ids) do
    certificates =
      from(c in Certificate,
        where: c.user_id == ^scope.user.id and c.participant_id in ^participant_ids,
        select: {c.status, c.emailed_at}
      )
      |> Repo.all()

    no_email =
      from(p in Participant,
        where: p.user_id == ^scope.user.id and p.id in ^participant_ids,
        where: is_nil(p.email) or p.email == "",
        select: count(p.id)
      )
      |> Repo.one()

    %{
      total: length(participant_ids),
      regenerate:
        Enum.count(certificates, fn {status, _} -> status not in [:pending, :processing] end),
      sent: Enum.count(certificates, fn {_, emailed_at} -> not is_nil(emailed_at) end),
      no_email: no_email
    }
  end

  def batch_stats(%Scope{} = scope, batch_id) do
    total =
      from(p in Participant,
        where: p.user_id == ^scope.user.id and p.batch_id == ^batch_id,
        select: count(p.id)
      )
      |> Repo.one()

    certificates =
      from(c in Certificate,
        where: c.user_id == ^scope.user.id and c.batch_id == ^batch_id
      )
      |> Repo.all()

    %{
      total: total,
      generated: Enum.count(certificates, &(&1.status == :ready)),
      pending: Enum.count(certificates, &(&1.status in [:pending, :processing])),
      failed: Enum.count(certificates, &(&1.status == :failed)),
      sent: Enum.count(certificates, &(not is_nil(&1.emailed_at))),
      no_email:
        from(p in Participant,
          where: p.user_id == ^scope.user.id and p.batch_id == ^batch_id,
          where: is_nil(p.email) or p.email == "",
          select: count(p.id)
        )
        |> Repo.one()
    }
  end

  defp count_selection(query, selection) do
    query
    |> apply_selection(selection)
    |> select([p], count(p.id, :distinct))
    |> Repo.one()
  end

  defp participants_query(%Scope{} = scope, filters) do
    from(p in Participant,
      join: b in assoc(p, :batch),
      join: e in assoc(b, :event),
      left_join: c in assoc(p, :certificate),
      where: p.user_id == ^scope.user.id
    )
    |> filter_query(filters)
  end

  defp filter_query(query, filters) do
    query =
      case normalize(filters["q"]) do
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
      case normalize(filters["event_id"]) do
        nil -> query
        event_id -> where(query, [p, b, e], e.id == ^event_id)
      end

    case normalize(filters["batch_id"]) do
      nil -> query
      batch_id -> where(query, [p], p.batch_id == ^batch_id)
    end
  end

  defp apply_selection(query, :all), do: query

  defp apply_selection(query, :not_generated) do
    where(query, [p, _b, _e, c], is_nil(c.id))
  end

  defp apply_selection(query, :not_sent) do
    where(
      query,
      [p, _b, _e, c],
      not is_nil(c.id) and c.status == :ready and is_nil(c.emailed_at)
    )
  end

  defp apply_selection(query, :error) do
    where(
      query,
      [p, _b, _e, c],
      c.status == :failed or c.email_status == :failed
    )
  end

  defp apply_selection(query, :no_email) do
    where(query, [p], is_nil(p.email) or p.email == "")
  end

  defp normalize(nil), do: nil

  defp normalize(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  defp normalize(value), do: to_string(value)
end
