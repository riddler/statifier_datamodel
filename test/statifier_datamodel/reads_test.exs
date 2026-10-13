defmodule StatifierDatamodel.ReadsTest do
  @moduledoc """
  ADR-0004 decision 6 - the read check over reads handed in as data.

  The record's worked example, the library loan, is transcribed below, and
  every row of its read-check table is asserted. The fixture reads further
  down are the paths real conditions yield: each one is what
  `Predicator.Analysis.references/1` answered for the condition quoted
  beside it at predicator 9.5.0, written by hand, because this package
  takes no dependency on the expression language, not even in its tests.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Reads

  alias StatifierDatamodel.Reads

  # ADR-0004's "Worked example" document, transcribed.
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

  defp read(events, path, location \\ nil),
    do: %{events: events, path: path, location: location}

  # The answer, or the exception it raised, so a raise fails an assertion.
  defp total(answer) do
    answer.()
  rescue
    error -> {:raised, error.__struct__}
  end

  # The reasons reported for one read, in order.
  defp reasons(document, read) do
    document |> Reads.undeclared([read]) |> Enum.map(fn {^read, reason} -> reason end)
  end

  describe "the worked example" do
    # Sabotage: answering :declared for every string segment under a
    # declared record (no field lookup) turned this test red at the
    # fine_cents row; reverted.
    test "answers every row of ADR-0004 decision 6's table" do
      rows = [
        {["loan.renewed"], ["_event", "data", "due_on"], []},
        {["loan.renewed"], ["_event", "data", "holds", 0, "patron_id"], []},
        {["loan.renewed"], ["_event", "data", "fine_cents"],
         [{:undeclared, "loan.renewed", ["_event", "data", "fine_cents"]}]},
        {["loan"], ["_event", "data", "copy_id"], []},
        {["loan"], ["_event", "data", "due_on"],
         [{:undeclared, "loan.returned", ["_event", "data", "due_on"]}]},
        {["loan.renewed", "loan.returned"], ["_event", "data", "returned_at"],
         [{:undeclared, "loan.renewed", ["_event", "data", "returned_at"]}]},
        {["*"], ["_event", "data", "copy_id"], []},
        {["loan.renewed"], ["_event", "data", :dynamic, "title"], []},
        {["loan.renewed"], ["_event", "name"], []},
        {["patron.registered"], ["_event", "data", "patron_id"], [:no_declared_event]},
        {[], ["loan", "due_on"], []},
        {[], ["loan", "fine_cents"], [{:undeclared_path, ["loan", "fine_cents"]}]}
      ]

      for {events, path, expected} <- rows do
        assert {events, path, reasons(@worked, read(events, path))} == {events, path, expected}
      end
    end

    # Sabotage: dropping the location from each answered read (answering
    # the read with location: nil) turned this test red; reverted.
    test "answers in input order, each read as it was handed in" do
      reads = [
        read([], ["loan", "fine_cents"], {:chart, "renewal", 3}),
        read(["loan.renewed"], ["_event", "data", "due_on"], {:chart, "renewal", 4}),
        read(["patron.registered"], ["_event", "data", "patron_id"], "line 9")
      ]

      assert Reads.undeclared(@worked, reads) == [
               {Enum.at(reads, 0), {:undeclared_path, ["loan", "fine_cents"]}},
               {Enum.at(reads, 2), :no_declared_event}
             ]
    end
  end

  describe "reads real conditions yield" do
    # Each read is what references/1 answered at predicator 9.5.0 for the
    # condition beside it; the location is the condition and its position.
    @fixtures [
      # "_event.data.due_on < today()" on loan.renewed
      {["loan.renewed"], ["_event", "data", "due_on"], []},
      # "_event.data.holds[0].patron_id == 'p-77'" on loan.renewed
      {["loan.renewed"], ["_event", "data", "holds", 0, "patron_id"], []},
      # "_event.data.holds[i].patron_id == 'p-77'" on loan.renewed: two reads
      {["loan.renewed"], ["_event", "data", "holds", :dynamic, "patron_id"], []},
      {["loan.renewed"], ["i"], [{:undeclared_path, ["i"]}]},
      # "_event.data['due_on'] != null" on loan.renewed: a string key is a name
      {["loan.renewed"], ["_event", "data", "due_on"], []},
      # "len(_event.data.holds) > 0 and _event.name == 'loan.renewed'"
      {["loan.renewed"], ["_event", "data", "holds"], []},
      {["loan.renewed"], ["_event", "name"], []},
      # "_event.data.holds[0] == null" on loan.renewed
      {["loan.renewed"], ["_event", "data", "holds", 0], []},
      # "_event.data.renewals + 1 > limits.max" on loan.renewed: two reads
      {["loan.renewed"], ["_event", "data", "renewals"], []},
      {["loan.renewed"], ["limits", "max"], [{:undeclared_path, ["limits", "max"]}]},
      # "loan.due_on < _event.data.due_on" on loan: two reads
      {["loan"], ["loan", "due_on"], []},
      {["loan"], ["_event", "data", "due_on"],
       [{:undeclared, "loan.returned", ["_event", "data", "due_on"]}]},
      # "_event.data" on loan.returned: the payload itself
      {["loan.returned"], ["_event", "data"], []},
      # "_event[k] == 1" on loan.returned: a computed field, then its key
      {["loan.returned"], ["_event", :dynamic], []},
      {["loan.returned"], ["k"], [{:undeclared_path, ["k"]}]},
      # "_sessionid == 'a'" with no event: an SCXML system variable
      {[], ["_sessionid"], [{:undeclared_path, ["_sessionid"]}]}
    ]

    # Sabotage: treating an integer segment as a field name under a list
    # (so holds[0] was not declared) turned this test red at the first
    # holds row; reverted.
    test "each answers as the rules say" do
      for {events, path, expected} <- @fixtures do
        assert {events, path, reasons(@worked, read(events, path))} == {events, path, expected}
      end
    end

    # Sabotage: answering one reason per read rather than one per failing
    # event (Enum.take(1)) turned this test red; reverted.
    test "a read under several matched events carries one reason per event it fails on" do
      assert reasons(
               @worked,
               read(["loan.renewed", "loan.returned"], ["_event", "data", "shelf"])
             ) ==
               [
                 {:undeclared, "loan.renewed", ["_event", "data", "shelf"]},
                 {:undeclared, "loan.returned", ["_event", "data", "shelf"]}
               ]
    end
  end

  describe "matching an event name" do
    # Sabotage: matching a name as a plain string prefix (no token
    # boundary) turned this test red at "loan.re"; reverted.
    test "a token prefix matches and a partial token does not" do
      assert reasons(@worked, read(["loan.re"], ["_event", "data", "copy_id"])) ==
               [:no_declared_event]

      assert reasons(@worked, read(["loan.renewed.late"], ["_event", "data", "copy_id"])) ==
               [:no_declared_event]

      assert reasons(@worked, read(["loan"], ["_event", "data", "returned_at"])) == [
               {:undeclared, "loan.renewed", ["_event", "data", "returned_at"]}
             ]
    end

    # Sabotage: reading a descriptor ending ".*" as itself turned this test
    # red; reverted.
    test "a name ending .* matches as the name without it" do
      assert reasons(@worked, read(["loan.*"], ["_event", "data", "due_on"])) ==
               reasons(@worked, read(["loan"], ["_event", "data", "due_on"]))

      assert reasons(@worked, read(["loan.*"], ["_event", "data", "due_on"])) == [
               {:undeclared, "loan.returned", ["_event", "data", "due_on"]}
             ]
    end

    # Sabotage: matching "*" as a literal name turned this test red;
    # reverted.
    test "* matches every declared event, and a sends entry is not an event received" do
      assert reasons(@worked, read(["*"], ["_event", "data", "returned_at"])) == [
               {:undeclared, "loan.renewed", ["_event", "data", "returned_at"]}
             ]

      assert reasons(@worked, read(["patron.due_soon"], ["_event", "data", "patron_id"])) ==
               [:no_declared_event]
    end

    # Sabotage: matching every declared event when the names are not a
    # list turned this test red at the nil names; reverted.
    test "a name that is not a string, or empty, matches nothing" do
      assert reasons(@worked, read([7, ""], ["_event", "data", "copy_id"])) ==
               [:no_declared_event]

      assert reasons(@worked, read(nil, ["_event", "data", "copy_id"])) == [:no_declared_event]
      assert reasons(@worked, read([], ["_event", "data", "copy_id"])) == [:no_declared_event]
    end
  end

  describe "the _event fields" do
    # Sabotage: removing "invokeid" from the system fields turned this test
    # red; reverted.
    test "every system field, and _event alone, is skipped" do
      for field <- ~w(name type sendid origin origintype invokeid) do
        assert reasons(@worked, read(["patron.registered"], ["_event", field])) == []
      end

      assert reasons(@worked, read(["loan.renewed"], ["_event"])) == []
      assert reasons(@worked, read(["loan.renewed"], ["_event", :dynamic, "x"])) == []
    end

    # Sabotage: skipping every field under _event other than data turned
    # this test red; reverted.
    test "any other field is reported on every matched event, or as naming no event" do
      assert reasons(@worked, read(["loan"], ["_event", "payload", "copy_id"])) == [
               {:undeclared, "loan.renewed", ["_event", "payload"]},
               {:undeclared, "loan.returned", ["_event", "payload"]},
               {:undeclared, "loan.lost", ["_event", "payload"]}
             ]

      assert reasons(@worked, read(["loan.renewed"], ["_event", 0])) == [
               {:undeclared, "loan.renewed", ["_event", 0]}
             ]

      assert reasons(@worked, read(["patron.registered"], ["_event", "payload"])) ==
               [:no_declared_event]
    end
  end

  describe "descending a payload type" do
    @descent %{
      "scopes" => [],
      "types" => [
        %{
          "name" => "loans.copy",
          "kind" => "record",
          "fields" => [
            %{"name" => "title", "type" => "string"},
            %{"name" => "branch", "type" => "loans.branch"},
            %{"name" => "shelf", "type" => "loans.shelf_mark"},
            %{"name" => "notes", "type" => "list"},
            %{"name" => "tags", "type" => "list", "item_type" => "string"},
            %{"name" => "grid", "type" => "list", "item_type" => "list"},
            %{"name" => "extra", "type" => "object"}
          ]
        },
        %{
          "name" => "loans.branch",
          "kind" => "shape",
          "fields" => [%{"name" => "code", "type" => "string", "required?" => true}]
        }
      ],
      "events" => [
        %{"name" => "copy.shelved", "type" => "loans.copy"},
        %{"name" => "copy.moved", "type" => "loans.relocation"},
        %{"name" => "copy.batch", "type" => "list"},
        %{"name" => "copy.noted", "type" => "string"}
      ]
    }

    defp descent(event, rest), do: reasons(@descent, read([event], ["_event", "data" | rest]))

    defp undeclared(event, rest), do: [{:undeclared, event, ["_event", "data" | rest]}]

    # Sabotage: reading a declared shape as declaring no member turned this
    # test red at branch.code; reverted.
    test "a string names a field of a record or a shape" do
      assert descent("copy.shelved", ["title"]) == []
      assert descent("copy.shelved", ["branch", "code"]) == []

      assert descent("copy.shelved", ["branch", "name"]) ==
               undeclared("copy.shelved", ["branch", "name"])

      assert descent("copy.shelved", ["branch", 0]) == undeclared("copy.shelved", ["branch", 0])
    end

    # Sabotage: reading a nil field type as declaring nothing beneath it
    # turned this test red at shelf.aisle; reverted.
    test "an unknown type, a nil field type included, declares whatever lies beneath it" do
      assert descent("copy.shelved", ["shelf", "aisle", 3]) == []
      assert descent("copy.moved", ["from", "branch", "code"]) == []
      assert descent("copy.shelved", ["notes", 2, "text"]) == []
    end

    # Sabotage: descending a list's item type with a string segment turned
    # this test red at tags.first; reverted.
    test "an integer descends a list, and a string under a list is not declared" do
      assert descent("copy.shelved", ["tags", 0]) == []

      assert descent("copy.shelved", ["tags", 0, "length"]) ==
               undeclared("copy.shelved", ["tags", 0, "length"])

      assert descent("copy.shelved", ["tags", "first"]) ==
               undeclared("copy.shelved", ["tags", "first"])

      assert descent("copy.shelved", ["grid", 0, 1, "x"]) == []
      assert descent("copy.batch", [0, "anything"]) == []
      assert descent("copy.batch", ["count"]) == undeclared("copy.batch", ["count"])
    end

    # Sabotage: letting a bare object declare any member turned this test
    # red at extra.note; reverted.
    test "object and the other scalars declare no member" do
      assert descent("copy.shelved", ["extra"]) == []

      assert descent("copy.shelved", ["extra", "note"]) ==
               undeclared("copy.shelved", ["extra", "note"])

      assert descent("copy.shelved", ["title", "length"]) ==
               undeclared("copy.shelved", ["title", "length"])

      assert descent("copy.noted", ["length"]) == undeclared("copy.noted", ["length"])
      assert descent("copy.noted", []) == []
    end

    # Sabotage: removing the clause that ends the descent at a segment
    # that is neither a name nor an index turned this test red at the
    # computed key; reverted.
    test "a computed key, or a segment that is neither a name nor an index, ends the check" do
      assert descent("copy.shelved", ["branch", :dynamic, "nothing"]) == []
      assert descent("copy.shelved", ["branch", 1.5, "nothing"]) == []
    end
  end

  describe "other roots" do
    # Sabotage: checking other roots when the document declares no path
    # turned this test red; reverted.
    test "a document declaring no path reports nothing for them" do
      document = %{"scopes" => [], "events" => [%{"name" => "loan.renewed", "type" => "object"}]}

      assert reasons(document, read([], ["loan", "fine_cents"])) == []
      assert reasons(document, read([], ["_sessionid"])) == []
    end

    # Sabotage: joining every segment, not only the leading strings, turned
    # this test red at the indexed read; reverted.
    test "the checked prefix ends at the first segment that is not a string" do
      assert reasons(@worked, read([], ["loan", "due_on", 0, "x"])) == []
      assert reasons(@worked, read([], ["loan", :dynamic, "x"])) == [{:undeclared_path, ["loan"]}]

      assert reasons(@worked, read([], ["loan", "due_on", "year"])) ==
               [{:undeclared_path, ["loan", "due_on", "year"]}]

      assert reasons(@worked, read([], [:dynamic, "x"])) == []
      assert reasons(@worked, read([], [])) == []
    end

    # Sabotage: checking only a read's root against the declared paths
    # turned this test red at loan.renewals; reverted.
    test "a declared object path declares its own fields beneath it" do
      document = %{
        "scopes" => [
          %{
            "scope" => "local",
            "entries" => [
              %{
                "path" => "loan",
                "type" => "object",
                "fields" => [%{"path" => "loan.copy_id", "type" => "string"}]
              }
            ]
          }
        ]
      }

      assert reasons(document, read([], ["loan"])) == []
      assert reasons(document, read([], ["loan", "copy_id"])) == []

      assert reasons(document, read([], ["loan", "renewals"])) == [
               {:undeclared_path, ["loan", "renewals"]}
             ]
    end
  end

  describe "totality" do
    # Sabotage: indexing events from a map that is not a document turned
    # this test red; reverted.
    test "an input that is not a document reports nothing" do
      reads = [read(["loan.renewed"], ["_event", "data", "x"]), read([], ["loan", "x"])]

      assert Reads.undeclared(nil, reads) == []

      assert Reads.undeclared(
               %{"events" => [%{"name" => "loan.renewed", "type" => "object"}]},
               reads
             ) == []

      assert Reads.undeclared(["loan.renewed"], reads) == []
    end

    # Sabotage: reporting an entry that is not a read as naming no event
    # turned this test red; reverted.
    test "reads that are not a list, and entries that are not reads, report nothing" do
      assert Reads.undeclared(@worked, nil) == []
      assert Reads.undeclared(@worked, %{path: ["loan", "x"]}) == []
      assert Reads.undeclared(@worked, [nil, "loan.x", %{events: []}, %{path: "loan.x"}]) == []
    end

    # Sabotage: dropping the proper-list check on the reads in undeclared/2
    # turned this test red (a raise read as an answer); reverted.
    test "reads handed in as an improper list report nothing" do
      unmatched = read(["patron.registered"], ["_event", "data", "patron_id"])

      assert Reads.undeclared(@worked, [unmatched]) == [{unmatched, :no_declared_event}]
      assert total(fn -> Reads.undeclared(@worked, [unmatched | :more]) end) == []
    end

    # Sabotage: dropping the proper-list check on a read's path turned this
    # test red; reverted.
    test "a read whose path is an improper list is not a read" do
      for path <- [["loan" | :more], ["_event", "data" | :more], ["_event", "data", "x" | :more]] do
        assert total(fn -> Reads.undeclared(@worked, [read(["loan.renewed"], path)]) end) == []
      end
    end

    # Sabotage: dropping the proper-list check on a read's events turned
    # this test red; reverted.
    test "a read whose events is an improper list names no event" do
      improper = read(["loan.renewed" | :more], ["_event", "data", "copy_id"])

      assert total(fn -> reasons(@worked, improper) end) == [:no_declared_event]
    end

    # Sabotage: removing the ProperLists.document/1 call from undeclared/2
    # turned this test red at its first assertion; making
    # ProperLists.document/1 leave a proper list's items as they are turned
    # it red at the second; reverted each.
    test "an improper list in the document is read as absent" do
      due_on = %{"path" => "loan.due_on", "type" => "date"}
      patron = %{"scope" => "global", "entries" => [%{"path" => "patron.id", "type" => "string"}]}

      renewal = %{
        "name" => "loans.renewal",
        "kind" => "record",
        "fields" => [%{"name" => "due_on"}]
      }

      odd = %{
        "name" => "loans.renewal",
        "kind" => "record",
        "fields" => [%{"name" => "due_on"} | :x]
      }

      renewed = %{"name" => "loan.renewed", "type" => "loans.renewal"}
      local = read([], ["loan", "due_on"])
      payload = read(["loan.renewed"], ["_event", "data", "fine_cents"])

      check = fn document, a_read -> total(fn -> reasons(document, a_read) end) end

      assert check.(%{"scopes" => [patron | :more]}, payload) == []

      entries = %{"scope" => "local", "entries" => [due_on | :more]}

      assert check.(%{"scopes" => [entries, patron]}, local) == [
               {:undeclared_path, ["loan", "due_on"]}
             ]

      nested = %{"path" => "loan", "type" => "object", "fields" => [due_on | :more]}
      fields = %{"scope" => "local", "entries" => [nested]}

      assert check.(%{"scopes" => [fields, patron]}, local) == [
               {:undeclared_path, ["loan", "due_on"]}
             ]

      assert check.(%{"scopes" => [fields, patron]}, read([], ["loan"])) == []

      assert check.(%{"scopes" => [], "types" => [renewal], "events" => [renewed]}, payload) ==
               [{:undeclared, "loan.renewed", ["_event", "data", "fine_cents"]}]

      assert check.(
               %{"scopes" => [], "types" => [renewal | :more], "events" => [renewed]},
               payload
             ) == []

      assert check.(%{"scopes" => [], "types" => [odd], "events" => [renewed]}, payload) == []

      assert check.(
               %{"scopes" => [], "types" => [renewal], "events" => [renewed | :more]},
               payload
             ) ==
               [:no_declared_event]
    end

    # Sabotage: answering nothing for a payload read whose names match no
    # event turned this test red; reverted.
    test "a document declaring no events reports every payload read as naming no event" do
      document = %{"scopes" => []}

      assert reasons(document, read(["loan.renewed"], ["_event", "data", "copy_id"])) ==
               [:no_declared_event]

      assert reasons(document, read(["loan.renewed"], ["_event", "name"])) == []
    end
  end
end
