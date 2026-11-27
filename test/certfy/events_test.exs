defmodule Certfy.EventsTest do
  use Certfy.DataCase

  alias Certfy.Events

  describe "events" do
    alias Certfy.Events.Event

    import Certfy.AccountsFixtures, only: [user_scope_fixture: 0]
    import Certfy.EventsFixtures
    import Certfy.CertificatesFixtures

    @invalid_attrs %{name: nil, extra_data: nil}

    test "list_events/1 returns all scoped events" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)
      other_event = event_fixture(other_scope)
      assert Events.list_events(scope) == [event]
      assert Events.list_events(other_scope) == [other_event]
    end

    test "list_events_page/2 filters, sorts and paginates" do
      scope = user_scope_fixture()

      with_template =
        event_fixture(scope, %{
          name: "Com template",
          template_path: template_path(),
          template_report: pptx_report()
        })

      without_template = event_fixture(scope, %{name: "Sem template"})

      assert %{total: 2, items: items} = Events.list_events_page(scope, %{})
      assert length(items) == 2

      assert %{items: [found]} = Events.list_events_page(scope, %{"q" => "Com template"})
      assert found.id == with_template.id

      assert %{items: [found]} = Events.list_events_page(scope, %{"template" => "no"})
      assert found.id == without_template.id

      for i <- 1..26 do
        event_fixture(scope, %{name: "Evento #{String.pad_leading(to_string(i), 2, "0")}"})
      end

      page1 = Events.list_events_page(scope, %{})
      assert page1.total == 28
      assert length(page1.items) == 25
      assert page1.pages == 2

      page2 = Events.list_events_page(scope, %{"page" => "2"})
      assert page2.page == 2
      assert length(page2.items) == 3
    end

    test "get_event!/2 returns the event with given id" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      other_scope = user_scope_fixture()
      assert Events.get_event!(scope, event.id) == event
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(other_scope, event.id) end
    end

    test "create_event/2 with valid data creates a event" do
      scope = user_scope_fixture()
      valid_attrs = %{name: "some name", extra_data: %{}}

      assert {:ok, %Event{} = event} = Events.create_event(scope, valid_attrs)

      assert event.name == "some name"
      assert event.extra_data == %{}
      assert event.user_id == scope.user.id
    end

    test "create_event/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.create_event(scope, @invalid_attrs)
    end

    test "update_event/3 with valid data updates the event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      update_attrs = %{name: "some updated name", extra_data: %{}}

      assert {:ok, %Event{} = event} = Events.update_event(scope, event, update_attrs)

      assert event.name == "some updated name"
      assert event.extra_data == %{}
    end

    test "update_event_template/3 stores the path and report" do
      scope = user_scope_fixture()
      event = event_fixture(scope)

      assert {:ok, %Event{} = event} =
               Events.update_event_template(scope, event, %{
                 template_path: template_path(),
                 template_report: pptx_report()
               })

      assert event.template_path == template_path()
      assert event.template_report["slides"] == 1
    end

    test "update_event/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)

      assert_raise MatchError, fn ->
        Events.update_event(other_scope, event, %{})
      end
    end

    test "update_event/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Events.update_event(scope, event, @invalid_attrs)
      assert event == Events.get_event!(scope, event.id)
    end

    test "delete_event/2 deletes the event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      assert {:ok, %Event{}} = Events.delete_event(scope, event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(scope, event.id) end
    end

    test "delete_event/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)
      assert_raise MatchError, fn -> Events.delete_event(other_scope, event) end
    end

    test "change_event/2 returns a event changeset" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      assert %Ecto.Changeset{} = Events.change_event(scope, event)
    end
  end

  describe "batches" do
    alias Certfy.Events.Batch

    import Certfy.AccountsFixtures, only: [user_scope_fixture: 0]
    import Certfy.EventsFixtures

    @invalid_attrs %{name: nil, extra_data: nil}

    test "list_batches/1 returns all scoped batches" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      batch = batch_fixture(scope)
      other_batch = batch_fixture(other_scope)
      assert Events.list_batches(scope) == [batch]
      assert Events.list_batches(other_scope) == [other_batch]
    end

    test "list_batches/2 returns only batches for the given event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      other_event = event_fixture(scope)
      batch = batch_fixture(scope, event)
      other_batch = batch_fixture(scope, other_event)

      assert Events.list_batches(scope, event) == [batch]
      assert Events.list_batches(scope, other_event) == [other_batch]
    end

    test "list_batches_page/2 filters by event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      other_event = event_fixture(scope)
      batch = batch_fixture(scope, event)
      other_batch = batch_fixture(scope, other_event)

      assert %{total: 2} = Events.list_batches_page(scope, %{})

      assert %{items: [found]} =
               Events.list_batches_page(scope, %{"event_id" => event.id})

      assert found.id == batch.id
      refute found.id == other_batch.id
    end

    test "get_batch!/2 returns the batch with given id" do
      scope = user_scope_fixture()
      batch = batch_fixture(scope)
      other_scope = user_scope_fixture()
      assert Events.get_batch!(scope, batch.id) == batch
      assert_raise Ecto.NoResultsError, fn -> Events.get_batch!(other_scope, batch.id) end
    end

    test "get_batch!/3 returns the batch for the given event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      other_event = event_fixture(scope)
      batch = batch_fixture(scope, event)

      assert Events.get_batch!(scope, event, batch.id) == batch

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_batch!(scope, other_event, batch.id)
      end
    end

    test "create_batch/3 with valid data creates a batch" do
      valid_attrs = %{name: "some name", extra_data: %{}}
      scope = user_scope_fixture()
      event = event_fixture(scope)

      assert {:ok, %Batch{} = batch} = Events.create_batch(scope, event, valid_attrs)
      assert batch.name == "some name"
      assert batch.extra_data == %{}
      assert batch.event_id == event.id
      assert batch.user_id == scope.user.id
    end

    test "create_batch/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      event = event_fixture(scope)

      assert {:error, %Ecto.Changeset{}} = Events.create_batch(scope, event, @invalid_attrs)
    end

    test "create_batch/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)

      assert_raise MatchError, fn -> Events.create_batch(other_scope, event, %{name: "name"}) end
    end

    test "update_batch/3 with valid data updates the batch" do
      scope = user_scope_fixture()
      batch = batch_fixture(scope)
      update_attrs = %{name: "some updated name", extra_data: %{}}

      assert {:ok, %Batch{} = batch} = Events.update_batch(scope, batch, update_attrs)
      assert batch.name == "some updated name"
      assert batch.extra_data == %{}
    end

    test "update_batch/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      batch = batch_fixture(scope)

      assert_raise MatchError, fn ->
        Events.update_batch(other_scope, batch, %{})
      end
    end

    test "update_batch/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      batch = batch_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Events.update_batch(scope, batch, @invalid_attrs)
      assert batch == Events.get_batch!(scope, batch.id)
    end

    test "delete_batch/2 deletes the batch" do
      scope = user_scope_fixture()
      batch = batch_fixture(scope)
      assert {:ok, %Batch{}} = Events.delete_batch(scope, batch)
      assert_raise Ecto.NoResultsError, fn -> Events.get_batch!(scope, batch.id) end
    end

    test "delete_batch/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      batch = batch_fixture(scope)
      assert_raise MatchError, fn -> Events.delete_batch(other_scope, batch) end
    end

    test "change_batch/2 returns a batch changeset" do
      scope = user_scope_fixture()
      batch = batch_fixture(scope)
      assert %Ecto.Changeset{} = Events.change_batch(scope, batch)
    end
  end

  describe "admin access" do
    import Certfy.AccountsFixtures, only: [admin_scope_fixture: 0, user_scope_fixture: 0]
    import Certfy.EventsFixtures

    setup do
      owner = user_scope_fixture()
      event = event_fixture(owner)
      batch = batch_fixture(owner, event)
      participant = participant_fixture(owner, batch)

      %{
        admin: admin_scope_fixture(),
        owner: owner,
        event: event,
        batch: batch,
        participant: participant
      }
    end

    test "lists and gets records of every user", %{
      admin: admin,
      event: event,
      batch: batch,
      participant: participant
    } do
      assert event.id in Enum.map(Events.list_events(admin), & &1.id)
      assert batch.id in Enum.map(Events.list_batches(admin), & &1.id)
      assert participant.id in Enum.map(Events.list_participants(admin), & &1.id)

      assert %{total: 1} = Events.list_events_page(admin, %{})
      assert %{total: 1} = Events.list_participants_page_all(admin, %{})
      assert Events.get_event!(admin, event.id).id == event.id
      assert Events.get_batch!(admin, batch.id).id == batch.id
      assert Events.get_participant!(admin, participant.id).id == participant.id
      assert Events.count_participants_for_event(admin, event) == 1
      assert [%{id: id}] = Events.list_participants_for_event(admin, event)
      assert id == participant.id
    end

    test "keeps the original owner when updating", %{admin: admin, event: event} do
      {:ok, updated} = Events.update_event(admin, event, %{name: "Editado pelo admin"})

      assert updated.name == "Editado pelo admin"
      assert updated.user_id == event.user_id
    end

    test "creates children for the owner of the parent record", %{
      admin: admin,
      event: event,
      batch: batch,
      owner: owner
    } do
      {:ok, created_batch} = Events.create_batch(admin, event, %{name: "Turma do admin"})
      assert created_batch.user_id == owner.user.id

      {:ok, created_participant} = Events.create_participant(admin, batch, %{name: "Maria"})
      assert created_participant.user_id == owner.user.id
    end

    test "keeps other records hidden for regular users", %{event: event} do
      other = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(other, event.id) end
      refute event.id in Enum.map(Events.list_events(other), & &1.id)
    end
  end

  describe "participants" do
    alias Certfy.Events.Participant

    import Certfy.AccountsFixtures, only: [user_scope_fixture: 0]
    import Certfy.EventsFixtures

    @invalid_attrs %{name: nil, email: nil, extra_data: nil}

    test "list_participants/1 returns all scoped participants" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      participant = participant_fixture(scope)
      other_participant = participant_fixture(other_scope)
      assert Events.list_participants(scope) == [participant]
      assert Events.list_participants(other_scope) == [other_participant]
    end

    test "list_participants/2 returns only participants for the given batch" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)
      other_batch = batch_fixture(scope, event)
      participant = participant_fixture(scope, batch)
      other_participant = participant_fixture(scope, other_batch)

      assert Events.list_participants(scope, batch) == [participant]
      assert Events.list_participants(scope, other_batch) == [other_participant]
    end

    test "list_participants_page/3 filters and paginates" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)
      with_email = participant_fixture(scope, batch, %{name: "Maria", email: "maria@example.com"})
      no_email = participant_fixture(scope, batch, %{name: "João", email: nil})

      assert %{total: 2} = Events.list_participants_page(scope, batch, %{})

      assert %{items: [found]} =
               Events.list_participants_page(scope, batch, %{"q" => "maria"})

      assert found.id == with_email.id

      assert %{items: [found]} =
               Events.list_participants_page(scope, batch, %{"email" => "without"})

      assert found.id == no_email.id

      for i <- 1..26 do
        participant_fixture(scope, batch, %{
          name: "Pessoa #{String.pad_leading(to_string(i), 2, "0")}"
        })
      end

      page1 = Events.list_participants_page(scope, batch, %{})
      assert page1.total == 28
      assert length(page1.items) == 25
      assert page1.pages == 2

      page2 = Events.list_participants_page(scope, batch, %{"page" => "2"})
      assert page2.page == 2
      assert length(page2.items) == 3
    end

    test "list_participants_page_all/2 filters by event and batch" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)
      other_event = event_fixture(scope)
      other_batch = batch_fixture(scope, other_event)
      participant = participant_fixture(scope, batch)
      other_participant = participant_fixture(scope, other_batch)

      assert %{total: 2} = Events.list_participants_page_all(scope, %{})

      assert %{items: [found]} =
               Events.list_participants_page_all(scope, %{"event_id" => event.id})

      assert found.id == participant.id
      refute found.id == other_participant.id

      assert %{items: [found]} =
               Events.list_participants_page_all(scope, %{"batch_id" => other_batch.id})

      assert found.id == other_participant.id
    end

    test "get_participant!/2 returns the participant with given id" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      other_scope = user_scope_fixture()
      assert Events.get_participant!(scope, participant.id) == participant

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_participant!(other_scope, participant.id)
      end
    end

    test "get_participant!/3 returns the participant for the given batch" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)
      other_batch = batch_fixture(scope, event)
      participant = participant_fixture(scope, batch)

      assert Events.get_participant!(scope, batch, participant.id) == participant

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_participant!(scope, other_batch, participant.id)
      end
    end

    test "create_participant/3 with valid data creates a participant" do
      valid_attrs = %{name: "some name", email: "some@email.com", extra_data: %{}}
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)

      assert {:ok, %Participant{} = participant} =
               Events.create_participant(scope, batch, valid_attrs)

      assert participant.name == "some name"
      assert participant.email == "some@email.com"
      assert participant.extra_data == %{}
      assert participant.batch_id == batch.id
      assert participant.user_id == scope.user.id
    end

    test "create_participant/3 without email creates a participant" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)

      assert {:ok, %Participant{} = participant} =
               Events.create_participant(scope, batch, %{name: "sem email", email: ""})

      assert participant.name == "sem email"
      assert is_nil(participant.email)
    end

    test "create_participant/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)

      assert {:error, %Ecto.Changeset{}} = Events.create_participant(scope, batch, @invalid_attrs)
    end

    test "create_participant/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)

      assert_raise MatchError, fn ->
        Events.create_participant(other_scope, batch, %{name: "name", email: "some@email.com"})
      end
    end

    test "update_participant/3 with valid data updates the participant" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        email: "some.updated@email.com",
        extra_data: %{}
      }

      assert {:ok, %Participant{} = participant} =
               Events.update_participant(scope, participant, update_attrs)

      assert participant.name == "some updated name"
      assert participant.email == "some.updated@email.com"
      assert participant.extra_data == %{}
    end

    test "update_participant/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      participant = participant_fixture(scope)

      assert_raise MatchError, fn ->
        Events.update_participant(other_scope, participant, %{})
      end
    end

    test "update_participant/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Events.update_participant(scope, participant, @invalid_attrs)

      assert participant == Events.get_participant!(scope, participant.id)
    end

    test "delete_participant/2 deletes the participant" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      assert {:ok, %Participant{}} = Events.delete_participant(scope, participant)
      assert_raise Ecto.NoResultsError, fn -> Events.get_participant!(scope, participant.id) end
    end

    test "delete_participant/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      participant = participant_fixture(scope)
      assert_raise MatchError, fn -> Events.delete_participant(other_scope, participant) end
    end

    test "change_participant/2 returns a participant changeset" do
      scope = user_scope_fixture()
      participant = participant_fixture(scope)
      assert %Ecto.Changeset{} = Events.change_participant(scope, participant)
    end

    test "import_participants/3 inserts every valid row without deduplicating" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)

      rows = [
        %{
          name: "Maria Silva",
          email: "maria@example.com",
          extra_data: %{"Cidade" => "Fortaleza"}
        },
        %{name: "Maria Silva", email: nil, extra_data: %{}},
        %{name: "João Souza", email: "joao@example.com", extra_data: %{}}
      ]

      assert {:ok, 3} = Events.import_participants(scope, batch, rows)

      participants = Events.list_participants(scope, batch)

      assert length(participants) == 3
      assert Enum.count(participants, &(&1.name == "Maria Silva")) == 2

      maria = Enum.find(participants, &(&1.email == "maria@example.com"))
      assert maria.extra_data == %{"Cidade" => "Fortaleza"}
      assert maria.user_id == scope.user.id
      assert maria.batch_id == batch.id

      assert Enum.any?(participants, &(&1.email == nil))
    end

    test "import_participants/3 with another user's batch raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)
      batch = batch_fixture(scope, event)

      assert_raise MatchError, fn ->
        Events.import_participants(other_scope, batch, [
          %{name: "Maria", email: nil, extra_data: %{}}
        ])
      end
    end
  end
end
