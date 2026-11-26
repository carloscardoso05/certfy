defmodule Certfy.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Certfy.Events` context.
  """

  @doc """
  Generate a unique event name.
  """
  def unique_event_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a event.
  """
  def event_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        extra_data: %{},
        name: unique_event_name(),
        template_path: "some template_path"
      })

    {:ok, event} = Certfy.Events.create_event(scope, attrs)
    event
  end

  @doc """
  Generate a unique batch name.
  """
  def unique_batch_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a batch.
  """
  def batch_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        extra_data: %{},
        name: unique_batch_name()
      })

    {:ok, batch} = Certfy.Events.create_batch(scope, attrs)
    batch
  end

  @doc """
  Generate a participant.
  """
  def participant_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: "some email",
        extra_data: %{},
        name: "some name"
      })

    {:ok, participant} = Certfy.Events.create_participant(scope, attrs)
    participant
  end
end
