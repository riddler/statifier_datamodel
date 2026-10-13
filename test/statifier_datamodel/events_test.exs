defmodule StatifierDatamodel.EventsTest do
  @moduledoc """
  ADR-0004 decisions 1-5, asserted where the reader lives.

  The record's worked example - the library loan, with three `events`
  entries that index, one repeated name, one nameless entry and one `sends`
  entry - is transcribed below, so the assertions are against the document
  the record publishes rather than against one written to suit them. The
  documents under `test/fixtures/documents/`, written before the two keys
  existed, are read too: each indexes no events and no sends, and gaining
  either key changes no answer any other reader gives.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Events

  alias StatifierDatamodel.{Declarations, Document, Events, Index}

  @fixtures Path.expand("../fixtures/documents", __DIR__)

  # ADR-0004's "Worked example" JSON, transcribed.
  @worked %{
    "version" => 1,
    "scopes" => [
      %{
        "scope" => "global",
        "label" => "Global",
        "description" => "Host-owned. The same for every execution of every chart.",
        "entries" => []
      },
      %{
        "scope" => "local",
        "label" => "Chart-local",
        "description" => "One per execution. Written by the chart as it goes.",
        "entries" => [
          %{"name" => "copy_id", "path" => "loan.copy_id", "type" => "string", "label" => "Copy"},
          %{"name" => "due_on", "path" => "loan.due_on", "type" => "date", "label" => "Due on"}
        ]
      },
      %{
        "scope" => "event",
        "label" => "Event",
        "description" => "The event being handled.",
        "entries" => [
          %{
            "name" => "event.name",
            "path" => "event.name",
            "type" => "string",
            "label" => "Event name"
          }
        ]
      }
    ],
    "types" => [
      %{
        "name" => "loans.renewal",
        "kind" => "record",
        "label" => "Renewal",
        "fields" => [
          %{"name" => "copy_id", "type" => "string", "required?" => true},
          %{"name" => "due_on", "type" => "date", "required?" => true},
          %{"name" => "renewals", "type" => "integer", "required?" => true},
          %{"name" => "holds", "type" => "list", "item_type" => "loans.hold"}
        ]
      },
      %{
        "name" => "loans.hold",
        "kind" => "record",
        "label" => "Hold",
        "fields" => [%{"name" => "patron_id", "type" => "string", "required?" => true}]
      },
      %{
        "name" => "loans.return",
        "kind" => "record",
        "label" => "Return",
        "fields" => [
          %{"name" => "copy_id", "type" => "string", "required?" => true},
          %{"name" => "returned_at", "type" => "datetime", "required?" => true},
          %{"name" => "condition", "type" => "string", "one_of" => ["good", "damaged"]}
        ]
      },
      %{
        "name" => "notices.due_soon",
        "kind" => "shape",
        "label" => "Due-soon notice",
        "fields" => [
          %{"name" => "patron_id", "type" => "string", "required?" => true},
          %{"name" => "due_on", "type" => "date", "required?" => true}
        ]
      }
    ],
    "events" => [
      %{"name" => "loan.renewed", "type" => "loans.renewal", "label" => "Loan renewed"},
      %{"name" => "loan.returned", "type" => "loans.return", "label" => "Copy returned"},
      %{"name" => "loan.lost", "type" => "loans.loss", "label" => "Copy reported lost"},
      %{"name" => "loan.renewed", "type" => "object", "label" => "Renewed again"},
      %{"type" => "object", "label" => "No name"}
    ],
    "sends" => [
      %{
        "name" => "patron.due_soon",
        "type" => "notices.due_soon",
        "label" => "Due-soon notice",
        "note" => "Sent before the due date."
      }
    ]
  }

  defp fixture(name), do: @fixtures |> Path.join(name) |> File.read!() |> JSON.decode!()

  defp fixtures do
    @fixtures
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.sort()
    |> Enum.map(&{&1, fixture(&1)})
  end

  defp names(entries), do: Enum.map(entries, & &1.name)

  defp one(section, entry), do: Events.from_document(%{section => [entry]})

  describe "the worked example" do
    # Sabotage: resolving a spelling that names nothing to {:opaque, name}
    # instead of :unknown in events.ex turned this test red at loan.lost;
    # dropping the uniq_by on name turned it red with the second
    # loan.renewed; reverted each.
    test "indexes three events and one send, totally, in list order" do
      assert Events.from_document(@worked) == %{
               events: [
                 %{
                   name: "loan.renewed",
                   type: {:declared, "loans.renewal"},
                   label: "Loan renewed",
                   note: nil
                 },
                 %{
                   name: "loan.returned",
                   type: {:declared, "loans.return"},
                   label: "Copy returned",
                   note: nil
                 },
                 %{name: "loan.lost", type: :unknown, label: "Copy reported lost", note: nil}
               ],
               sends: [
                 %{
                   name: "patron.due_soon",
                   type: {:declared, "notices.due_soon"},
                   label: "Due-soon notice",
                   note: "Sent before the due date."
                 }
               ]
             }
    end

    # Sabotage: making unresolved/1 return its argument unfiltered turned
    # this test red; filtering on :opaque instead of :unknown turned it red;
    # reverted each.
    test "unresolved/1 answers loan.lost under events and nothing under sends" do
      assert %{events: [%{name: "loan.lost", type: :unknown}], sends: []} =
               @worked |> Events.from_document() |> Events.unresolved()
    end

    # Sabotage: making fetch/3 read the other section's list turned this
    # test red at the cross-section lookups; reverted.
    test "fetch/3 finds the first loan.renewed and keeps the sections apart" do
      events = Events.from_document(@worked)

      assert {:ok, %{type: {:declared, "loans.renewal"}, label: "Loan renewed"}} =
               Events.fetch(events, :events, "loan.renewed")

      assert {:ok, %{type: {:declared, "notices.due_soon"}}} =
               Events.fetch(events, :sends, "patron.due_soon")

      assert Events.fetch(events, :sends, "loan.renewed") == :error
      assert Events.fetch(events, :events, "patron.due_soon") == :error
      assert Events.fetch(events, :events, "loan.reserved") == :error
    end

    # Sabotage: making index/1 add each events entry's name to the
    # declared-path order (a flat_map over "events" in index.ex) turned
    # this test red; reverted.
    test "the two sections contribute no declared path and no path type" do
      without = Map.drop(@worked, ["events", "sends"])

      assert Document.declared_paths(@worked) ==
               MapSet.new(["loan.copy_id", "loan.due_on", "event.name"])

      assert Index.index(@worked) == Index.index(without)
      assert Index.path_types(Index.index(@worked)) == Index.path_types(Index.index(without))
    end
  end

  describe "an entry" do
    # Sabotage: dropping the `type != ""` guard in events.ex turned this
    # test red at the empty type; dropping `name != ""` turned it red at the
    # empty name; reverted each.
    test "missing name or type, or carrying either as anything but a non-empty string, declares nothing" do
      for half <- [
            %{"type" => "object"},
            %{"name" => "loan.renewed"},
            %{"name" => "", "type" => "object"},
            %{"name" => "loan.renewed", "type" => ""},
            %{"name" => 7, "type" => "object"},
            %{"name" => "loan.renewed", "type" => :object},
            %{"name" => "loan.renewed", "type" => %{"fields" => []}},
            %{"name" => "loan.renewed", "type" => nil},
            "loan.renewed",
            nil
          ],
          section <- ["events", "sends"] do
        assert {half, %{events: [], sends: []}} == {half, one(section, half)}
      end
    end

    # Sabotage: reading label without the string check in events.ex turned
    # this test red; reverted.
    test "a label or note that is not a string is nil, and the entry still declares" do
      assert %{events: [%{name: "loan.renewed", type: :object, label: nil, note: nil}]} =
               one("events", %{
                 "name" => "loan.renewed",
                 "type" => "object",
                 "label" => 5,
                 "note" => ["prose"]
               })
    end

    # Sabotage: looking the declarations up before the closed set in
    # events.ex turned this test red at the "string" declaration; reverted.
    test "a type is one of the nine first, then a declared name, else unknown" do
      document = %{
        "types" => [
          %{"name" => "string", "kind" => "record", "label" => "Shadow", "fields" => []},
          %{"name" => "loans.hold", "kind" => "record", "label" => "Hold", "fields" => []}
        ],
        "events" =>
          for(
            type <-
              ~w(string integer decimal boolean datetime duration date object list) ++
                ["loans.hold", "loans.loss"],
            do: %{"name" => "on." <> type, "type" => type}
          )
      }

      assert Enum.map(Events.from_document(document).events, & &1.type) == [
               :string,
               :integer,
               :decimal,
               :boolean,
               :datetime,
               :duration,
               :date,
               :object,
               :list,
               {:declared, "loans.hold"},
               :unknown
             ]
    end

    # Sabotage: keeping the last occurrence (reversing the list around the
    # uniq_by) in events.ex turned this test red; reverted.
    test "a half-written entry does not take its name; the first whole one does" do
      events =
        Events.from_document(%{
          "events" => [
            %{"name" => "loan.renewed", "type" => 7},
            %{"name" => "loan.renewed", "type" => "object", "label" => "First whole"},
            %{"name" => "loan.renewed", "type" => "list", "label" => "Second whole"}
          ]
        })

      assert [%{label: "First whole", type: :object}] = events.events
    end

    # Sabotage: reading the `events` list for both sections in
    # from_document/1 turned this test red; making fetch/3 read the other
    # section's list turned it red; reverted each.
    test "the same name in both sections is two entries" do
      events =
        Events.from_document(%{
          "events" => [%{"name" => "loan.renewed", "type" => "object"}],
          "sends" => [%{"name" => "loan.renewed", "type" => "list"}]
        })

      assert {:ok, %{type: :object}} = Events.fetch(events, :events, "loan.renewed")
      assert {:ok, %{type: :list}} = Events.fetch(events, :sends, "loan.renewed")
    end
  end

  describe "unresolved/1" do
    # Sabotage: sorting each section by name in unresolved/1 turned this
    # test red; reverted.
    test "lists every unknown entry of each section in its own list order" do
      events =
        Events.from_document(%{
          "events" => [
            %{"name" => "z.first", "type" => "loans.zeta"},
            %{"name" => "m.known", "type" => "object"},
            %{"name" => "a.second", "type" => "loans.alpha"}
          ],
          "sends" => [
            %{"name" => "y.first", "type" => "notices.y"},
            %{"name" => "b.second", "type" => "notices.b"}
          ]
        })

      unresolved = Events.unresolved(events)
      assert names(unresolved.events) == ["z.first", "a.second"]
      assert names(unresolved.sends) == ["y.first", "b.second"]
      assert names(events.events) == ["z.first", "m.known", "a.second"]
    end
  end

  describe "totality" do
    # Sabotage: making unresolved/1's fallback answer `sends: nil` turned
    # this test red; reverted.
    test "anything that is not a document, an index or a known section answers empty or :error" do
      for input <- [nil, 7, "events", ["loan.renewed"], {:events, []}] do
        assert Events.from_document(input) == %{events: [], sends: []}
        assert Events.unresolved(input) == %{events: [], sends: []}
        assert Events.fetch(input, :events, "loan.renewed") == :error
      end

      for raw <- [nil, "loan.renewed", %{"name" => "loan.renewed"}, 7] do
        assert Events.from_document(%{"events" => raw, "sends" => raw}) ==
                 %{events: [], sends: []}
      end

      events = Events.from_document(@worked)
      assert Events.fetch(events, :types, "loan.renewed") == :error
      assert Events.fetch(events, :events, :loan_renewed) == :error
      assert Events.fetch(%{events: "not a list"}, :events, "loan.renewed") == :error
      assert Events.unresolved(%{events: "not a list"}) == %{events: [], sends: []}
    end
  end

  describe "documents written before the two keys" do
    # Sabotage: making index/1 add each events entry's name to the
    # declared-path order (a flat_map over "events" in index.ex) turned this
    # test red; reverted.
    test "declare no events and no sends, and gaining both keys changes no other answer" do
      assert [_ | _] = fixtures()

      for {name, document} <- fixtures() do
        assert {name, %{events: [], sends: []}} == {name, Events.from_document(document)}

        with_sections =
          Map.merge(document, %{"events" => @worked["events"], "sends" => @worked["sends"]})

        index = Index.index(document)
        assert {name, index} == {name, Index.index(with_sections)}

        assert {name, Index.path_types(index)} ==
                 {name, Index.path_types(Index.index(with_sections))}

        assert {name, Document.declared_paths(document)} ==
                 {name, Document.declared_paths(with_sections)}

        assert {name, Document.declared_values(document)} ==
                 {name, Document.declared_values(with_sections)}

        assert {name, Declarations.from_document(document)} ==
                 {name, Declarations.from_document(with_sections)}
      end
    end
  end
end
