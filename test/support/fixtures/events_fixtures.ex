defmodule Certfy.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the Certfy.Events context.
  """

  alias Certfy.Events.Batch
  alias Certfy.Events.Event

  @doc """
  Generate a unique event name.
  """
  def unique_event_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a event.
  """
  def event_fixture(scope, attrs \\ %{}) do
    {template_path, attrs} = Map.pop(attrs, :template_path)
    {template_report, attrs} = Map.pop(attrs, :template_report)

    attrs =
      Enum.into(attrs, %{
        extra_data: %{},
        name: unique_event_name()
      })

    {:ok, event} = Certfy.Events.create_event(scope, attrs)

    if template_path || template_report do
      {:ok, event} =
        Certfy.Events.update_event_template(scope, event, %{
          template_path: template_path,
          template_report: template_report || %{},
          template_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      event
    else
      event
    end
  end

  @doc """
  Generate a unique batch name.
  """
  def unique_batch_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a batch. When no event is given, one is created for the same scope.
  """
  def batch_fixture(scope, event_or_attrs \\ %{})

  def batch_fixture(scope, %Event{} = event), do: batch_fixture(scope, event, %{})

  def batch_fixture(scope, attrs) when is_map(attrs) do
    batch_fixture(scope, event_fixture(scope), attrs)
  end

  def batch_fixture(scope, %Event{} = event, attrs) do
    attrs =
      Enum.into(attrs, %{
        extra_data: %{},
        name: unique_batch_name()
      })

    {:ok, batch} = Certfy.Events.create_batch(scope, event, attrs)
    batch
  end

  @doc """
  Generate a participant. When no batch is given, an event and batch are created.
  """
  def participant_fixture(scope, batch_or_attrs \\ %{})

  def participant_fixture(scope, %Batch{} = batch), do: participant_fixture(scope, batch, %{})

  def participant_fixture(scope, attrs) when is_map(attrs) do
    event = event_fixture(scope)
    batch = batch_fixture(scope, event)
    participant_fixture(scope, batch, attrs)
  end

  def participant_fixture(scope, %Batch{} = batch, attrs) do
    attrs =
      Enum.into(attrs, %{
        email: "some@email.com",
        extra_data: %{},
        name: "some name"
      })

    {:ok, participant} = Certfy.Events.create_participant(scope, batch, attrs)
    participant
  end
end
