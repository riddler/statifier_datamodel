defmodule StatifierDatamodel.IndexTest do
  @moduledoc """
  ADR-0001, asserted where the reader lives.

  The record's own worked shape is the fixture below, transcribed including
  its `types` key, and the record states its projection's answer for it
  exactly - nine paths, "and nothing from `types`" - so the first describe
  asserts the record's arithmetic rather than the implementation's.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Index

  alias StatifierDatamodel.Index

  # ADR-0001's "Worked shape", transcribed - credit-card processing, one
  # entry per kind, and the four declarations the record's `types` key
  # carries. The declarations are here so the projection can be asserted
  # against a document that has them: decision 7 says `types` contributes
  # no path, and a fixture without the key could not show that.
  @worked_document %{
    "version" => 1,
    "scopes" => [
      %{
        "scope" => "global",
        "label" => "Global",
        "description" => "Host-owned. The same for every run of every chart.",
        "entries" => [
          %{
            "name" => "limits",
            "path" => "limits",
            "type" => "object",
            "label" => "Limits",
            "fields" => [
              %{
                "name" => "authorization_window",
                "path" => "limits.authorization_window",
                "type" => "duration",
                "label" => "Authorization window",
                "example" => "15m"
              }
            ]
          }
        ]
      },
      %{
        "scope" => "local",
        "label" => "Chart-local",
        "description" => "One per run. Written by the steps of the chart as it goes.",
        "entries" => [
          %{
            "name" => "amount_cents",
            "path" => "amount_cents",
            "type" => "integer",
            "label" => "Amount (minor units)",
            "example" => 42_350
          },
          %{
            "name" => "risk_reasons",
            "path" => "risk_reasons",
            "type" => "list",
            "item_type" => "string",
            "label" => "Risk reasons",
            "example" => ["velocity", "new_device"]
          },
          %{
            "name" => "card",
            "path" => "card",
            "type" => "object",
            "label" => "Card",
            "fields" => [
              %{
                "name" => "brand",
                "path" => "card.brand",
                "type" => "string",
                "label" => "Brand",
                "one_of" => ["visa", "mastercard", "amex"]
              },
              %{
                "name" => "last4",
                "path" => "card.last4",
                "type" => "string",
                "label" => "Last four"
              },
              %{
                "name" => "expires_on",
                "path" => "card.expires_on",
                "type" => "date",
                "label" => "Expires on",
                "example" => "2028-11-30"
              }
            ]
          }
        ]
      },
      %{
        "scope" => "event",
        "label" => "Event payload",
        "description" => "The payload of the event being handled.",
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
        "name" => "cards.credit_txn",
        "kind" => "record",
        "label" => "Credit transaction",
        "fields" => [
          %{"name" => "amount_cents", "type" => "integer", "required?" => true},
          %{
            "name" => "currency",
            "type" => "string",
            "required?" => true,
            "one_of" => ["USD", "EUR", "GBP"]
          },
          %{"name" => "card", "type" => "cards.card", "required?" => true},
          %{"name" => "authorized_at", "type" => "datetime", "required?" => true},
          %{"name" => "risk_reasons", "type" => "list", "item_type" => "string"}
        ]
      },
      %{
        "name" => "cards.card",
        "kind" => "record",
        "label" => "Card",
        "fields" => [
          %{"name" => "brand", "type" => "string", "required?" => true},
          %{"name" => "last4", "type" => "string", "required?" => true},
          %{"name" => "expires_on", "type" => "date", "required?" => true}
        ]
      },
      %{
        "name" => "Settleable",
        "kind" => "shape",
        "label" => "Settleable",
        "fields" => [
          %{"name" => "amount_cents", "type" => "integer", "required?" => true},
          %{"name" => "currency", "type" => "string", "required?" => true},
          %{"name" => "authorized_at", "type" => "datetime", "required?" => true}
        ]
      },
      %{
        "name" => "Refundable",
        "kind" => "shape",
        "label" => "Refundable",
        "fields" => [
          %{"name" => "amount_cents", "type" => "integer", "required?" => true},
          %{"name" => "settled_at", "type" => "datetime", "required?" => true}
        ]
      }
    ]
  }

  @worked_paths [
    "limits",
    "limits.authorization_window",
    "amount_cents",
    "risk_reasons",
    "card",
    "card.brand",
    "card.last4",
    "card.expires_on",
    "event.name"
  ]

  defp worked, do: Index.index(@worked_document)

  # A host that insists on describing the raw pan and the processor
  # credential.
  defp sensitive_document do
    document([
      %{"path" => "card.token_id", "type" => "string"},
      %{"path" => "card.number", "type" => "string", "sensitive?" => true},
      %{
        "path" => "processor",
        "type" => "object",
        "sensitive?" => true,
        "fields" => [%{"path" => "processor.api_key", "type" => "string"}]
      }
    ])
  end

  defp document(entries, scope \\ "local") do
    %{"version" => 1, "scopes" => [%{"scope" => scope, "entries" => entries}]}
  end

  describe "declared_paths/1 - ADR-0001 decision 7" do
    # sabotage: dropped the `fields` half of `entry/3`, so an object
    # contributed only itself - the set lost `limits.authorization_window`,
    # `card.brand`, `card.last4` and `card.expires_on` and this went red
    # (verified).
    test "the record's worked shape projects to exactly the nine paths it names" do
      assert Index.declared_paths(worked()) == MapSet.new(@worked_paths)
      assert MapSet.size(Index.declared_paths(worked())) == 9
    end

    # sabotage: indexed each declaration's `name` as a path - the four
    # declared names joined the set and this went red, which is the "and
    # nothing from `types`" half of the record's own arithmetic (verified).
    test "the types key contributes no path: a declared name is not a path" do
      declared = Index.declared_paths(worked())

      for name <- ["cards.credit_txn", "cards.card", "Settleable", "Refundable"] do
        refute MapSet.member?(declared, name)
        assert Index.declared?(worked(), name) == false
      end
    end

    # sabotage: made a `list` entry contribute `path <> "[]"` alongside its
    # own path - `risk_reasons[]` appeared in the set and this went red,
    # which is the alternative the record rejects by name (verified).
    test "a list contributes its own path alone, whatever its item_type" do
      index =
        Index.index(
          document([%{"path" => "risk_reasons", "type" => "list", "item_type" => "string"}])
        )

      assert Index.declared_paths(index) == MapSet.new(["risk_reasons"])
      assert Index.type(index, "risk_reasons") == :list
      assert {:ok, %{item_type: :string}} = Index.fetch(index, "risk_reasons")
    end

    # sabotage: had `index/1` return `nil` for an empty `scopes` list - the
    # empty document became "not a datamodel" and this went red, which is
    # the distinction decision 6 spends a paragraph on (verified).
    test "a document declaring nothing projects to the empty set, not to nil" do
      assert Index.declared_paths(Index.index(%{"version" => 1, "scopes" => []})) ==
               MapSet.new([])
    end

    # sabotage: kept the scope name as part of the path - `local:card`
    # entered the set and this went red (verified).
    test "scope names contribute nothing, and event entries carry their own prefix" do
      index =
        Index.index(%{
          "version" => 1,
          "scopes" => [
            %{"scope" => "local", "entries" => [%{"path" => "card.brand"}]},
            %{"scope" => "event", "entries" => [%{"path" => "event.name"}]}
          ]
        })

      assert Index.declared_paths(index) == MapSet.new(["card.brand", "event.name"])
    end
  end

  describe "index/1 - admission" do
    # sabotage: made `index/1` admit any map - a bare `%{}` produced an
    # empty index instead of `nil` and the nil assertions here went red,
    # which is what keeps "not a document" apart from "declares nothing"
    # (verified).
    test "admits a map carrying a scopes list, and nothing else" do
      assert %Index{} = Index.index(%{"scopes" => []})
      assert Index.index(%{"scopes" => "global"}) == nil
      assert Index.index(%{}) == nil
      assert Index.index(["card.brand"]) == nil
      assert Index.index(MapSet.new(["card.brand"])) == nil
      assert Index.index(nil) == nil
      assert Index.index(42) == nil
    end

    # sabotage: read `version` with `Map.get(document, "version", 1)` and no
    # integer guard, so `"1"` was carried through as a string - the third
    # assertion went red (verified).
    test "version defaults to 1 and is taken only when it is an integer" do
      assert Index.index(%{"scopes" => []}).version == 1
      assert Index.index(%{"version" => 2, "scopes" => []}).version == 2
      assert Index.index(%{"version" => "1", "scopes" => []}).version == 1
    end

    # sabotage: dropped the `is_list` guard on a scope's `entries`, which
    # raised a `Protocol.UndefinedError` out of `Enum.flat_map/2` instead of
    # returning an index - this went red on the raise (verified).
    test "a scope map missing or malforming its entries contributes nothing" do
      index =
        Index.index(%{
          "scopes" => [
            %{"scope" => "local"},
            %{"scope" => "local", "entries" => "card.brand"},
            "not a scope map",
            %{"scope" => "local", "entries" => [%{"path" => "card.brand"}]}
          ]
        })

      assert Index.declared_paths(index) == MapSet.new(["card.brand"])
    end

    # sabotage: took an entry's `path` with no non-empty-binary guard, so a
    # pathless entry contributed `nil` to the set - the MapSet comparison
    # went red with `nil` in it (verified).
    test "an entry with no usable path contributes none, and its fields are still walked" do
      index =
        Index.index(
          document([
            %{"name" => "card", "type" => "object", "fields" => [%{"path" => "card.brand"}]},
            %{"path" => "", "type" => "string"},
            %{"path" => 42, "type" => "string"},
            "not an entry map"
          ])
        )

      assert Index.declared_paths(index) == MapSet.new(["card.brand"])
    end

    # sabotage: carried an unknown `type` string through as an atom - the
    # `nil` assertions went red and the package would have grown a type by
    # accident (verified).
    test "a type outside the closed set normalizes to nil" do
      index =
        Index.index(
          document([
            %{"path" => "blob", "type" => "binary"},
            %{"path" => "count", "type" => "integer"},
            %{"path" => "weird", "type" => 7},
            %{"path" => "items", "type" => "list", "item_type" => "geo_point"}
          ])
        )

      assert Index.type(index, "blob") == nil
      assert Index.type(index, "count") == :integer
      assert Index.type(index, "weird") == nil
      assert {:ok, %{item_type: nil}} = Index.fetch(index, "items")
    end

    # sabotage: dropped `"date"` from the closed set, which is where it was
    # before ADR-0001 decision 4 widened it - `card.expires_on` and `born_on`
    # went back to `nil` and the `:date` assertions went red (verified).
    test "date indexes like the other scalars, at any depth and as an item_type" do
      assert Index.type(worked(), "card.expires_on") == :date

      assert {:ok, %{type: :date, depth: 1, example: "2028-11-30"}} =
               Index.fetch(worked(), "card.expires_on")

      index =
        Index.index(
          document([
            %{"path" => "born_on", "type" => "date"},
            %{"path" => "settlement_dates", "type" => "list", "item_type" => "date"}
          ])
        )

      assert Index.type(index, "born_on") == :date
      assert {:ok, %{item_type: :date}} = Index.fetch(index, "settlement_dates")
      assert Index.declared_paths(index) == MapSet.new(["born_on", "settlement_dates"])
    end

    # sabotage: replaced `Map.put_new/3` with `Map.put/3` in `dedupe/1`, so
    # the last occurrence won - the label assertion went red (verified).
    test "a repeated path keeps its first occurrence, and appears once in order" do
      index =
        Index.index(
          document([
            %{"path" => "card.brand", "label" => "First"},
            %{"path" => "card.brand", "label" => "Second"}
          ])
        )

      assert index.order == ["card.brand"]
      assert {:ok, %{label: "First"}} = Index.fetch(index, "card.brand")
    end

    # sabotage: dropped entries whose scope map named something outside the
    # three, so `sidecar`'s path vanished from the set - this went red, and
    # the record says scope names contribute nothing (verified).
    test "an unrecognized scope name indexes its entries with a nil scope" do
      index =
        Index.index(%{
          "scopes" => [%{"scope" => "sidecar", "entries" => [%{"path" => "card.brand"}]}]
        })

      assert Index.declared_paths(index) == MapSet.new(["card.brand"])
      assert {:ok, %{scope: nil}} = Index.fetch(index, "card.brand")
    end
  end

  describe "the entry normalization" do
    # sabotage: stamped every entry with `depth: 0`, so an object's fields
    # claimed to be top level - the depth assertions went red (verified).
    test "an entry carries the record's keys, its scope and its nesting depth" do
      index = worked()

      assert {:ok, entry} = Index.fetch(index, "limits.authorization_window")
      assert entry.name == "authorization_window"
      assert entry.path == "limits.authorization_window"
      assert entry.type == :duration
      assert entry.label == "Authorization window"
      assert entry.example == "15m"
      assert entry.scope == :global
      assert entry.depth == 1
      assert entry.sensitive? == false

      assert {:ok, %{depth: 0, scope: :local, type: :integer}} =
               Index.fetch(index, "amount_cents")

      assert {:ok, %{scope: :event}} = Index.fetch(index, "event.name")
    end

    # sabotage: read `one_of` and `note` with no shape guard, so a string
    # `one_of` was carried as a string - the `nil` assertion went red
    # (verified).
    test "the optional keys are taken only in the shape the record gives them" do
      index =
        Index.index(
          document([
            %{
              "path" => "fraud.verdict",
              "type" => "string",
              "note" => "The engine's call.",
              "one_of" => ["approve", "review", "decline"]
            },
            %{"path" => "fraud.score", "note" => 7, "one_of" => "approve"}
          ])
        )

      assert {:ok, verdict} = Index.fetch(index, "fraud.verdict")
      assert verdict.note == "The engine's call."
      assert verdict.one_of == ["approve", "review", "decline"]

      assert {:ok, %{note: nil, one_of: nil}} = Index.fetch(index, "fraud.score")
    end
  end

  describe "an entry typed by a declaration - ADR-0001 decisions 3, 6 and 7 as amended 2026-09-06" do
    # The record's two declarations, nested one inside the other, so an
    # expansion that stopped at the first level would be visible.
    @types [
      %{
        "name" => "cards.credit_txn",
        "kind" => "record",
        "label" => "Credit transaction",
        "fields" => [
          %{
            "name" => "amount_cents",
            "type" => "integer",
            "required?" => true,
            "label" => "Amount (minor units)"
          },
          %{"name" => "card", "type" => "cards.card", "required?" => true},
          %{"name" => "risk_reasons", "type" => "list", "item_type" => "string"}
        ]
      },
      %{
        "name" => "cards.card",
        "kind" => "record",
        "label" => "Card",
        "fields" => [
          %{
            "name" => "brand",
            "type" => "string",
            "label" => "Brand",
            "one_of" => ["visa", "mastercard", "amex"]
          }
        ]
      }
    ]

    defp typed(entries, types \\ @types) do
      Index.index(%{
        "version" => 1,
        "scopes" => [%{"scope" => "local", "entries" => entries}],
        "types" => types
      })
    end

    # sabotage: made `entry_type/2` answer `nil` for a name the closed set
    # does not carry, as it did before the amendment - seven of this
    # describe's nine tests went red and the entry contributed its own path
    # alone (verified).
    test "the entry's type is the declared name, and the declaration's fields expand beneath it" do
      index = typed([%{"name" => "txn", "path" => "txn", "type" => "cards.credit_txn"}])

      assert index.order == [
               "txn",
               "txn.amount_cents",
               "txn.card",
               "txn.card.brand",
               "txn.risk_reasons"
             ]

      assert Index.type(index, "txn") == {:declared, "cards.credit_txn"}
      assert Index.type(index, "txn.card") == {:declared, "cards.card"}
      assert Index.type(index, "txn.amount_cents") == :integer
      assert Index.type(index, "txn.card.brand") == :string
    end

    # sabotage: had `member/2` copy the parent entry's `example` and
    # `sensitive?` onto every expanded path - the `nil` and `false`
    # assertions went red, and a declaration would have been inventing keys
    # it does not carry (verified).
    test "an expanded path carries the field's keys, the entry's scope, and nothing invented" do
      index =
        typed([
          %{
            "name" => "txn",
            "path" => "txn",
            "type" => "cards.credit_txn",
            "example" => "ignored",
            "note" => "ignored",
            "sensitive?" => true
          }
        ])

      assert {:ok, brand} = Index.fetch(index, "txn.card.brand")
      assert brand.name == "brand"
      assert brand.label == "Brand"
      assert brand.one_of == ["visa", "mastercard", "amex"]
      assert brand.scope == :local
      assert brand.depth == 2
      assert brand.example == nil
      assert brand.note == nil
      assert brand.sensitive? == false

      assert {:ok, %{depth: 1, item_type: :string, type: :list}} =
               Index.fetch(index, "txn.risk_reasons")

      # The entry's own flag is still read literally, per entry.
      assert Index.sensitive_paths(index) == MapSet.new(["txn"])
    end

    # sabotage: dropped the `Map.get(@types, t)` arm from `entry_type/2` so
    # the declarations were consulted first - this assertion went red and a
    # document declaring `"string"` would have shadowed the scalar
    # (verified).
    test "the closed set wins over a declaration spelled the same way" do
      types = [%{"name" => "string", "kind" => "record", "label" => "String", "fields" => []}]
      index = typed([%{"path" => "note", "type" => "string"}], types)

      assert Index.type(index, "note") == :string
      assert index.order == ["note"]
    end

    # sabotage: made `entry_type/2` answer `{:declared, t}` for any string
    # outside the closed set - this test and "a type outside the closed set
    # normalizes to nil" both went red, and an entry typed by a name nothing
    # declares would have claimed a declaration (verified).
    test "a name the types key does not declare is unknown, and expands nothing" do
      index = typed([%{"path" => "note", "type" => "cards.nothing"}])

      assert Index.type(index, "note") == nil
      assert index.order == ["note"]
      assert Index.declared?(index, "note") == true
    end

    # sabotage: neutered the `MapSet.member?(seen, name)` guard in
    # `expand/3` - this test hung on the self-referencing document and died
    # of ExUnit's 60s timeout instead of answering, which is the totality
    # the guard buys (verified).
    test "a cycle between declarations discharges rather than recurring" do
      types = [
        %{
          "name" => "cards.node",
          "kind" => "record",
          "label" => "Node",
          "fields" => [
            %{"name" => "brand", "type" => "string"},
            %{"name" => "next", "type" => "cards.node"}
          ]
        }
      ]

      index = typed([%{"path" => "head", "type" => "cards.node"}], types)

      assert index.order == ["head", "head.brand", "head.next"]
      assert Index.type(index, "head.next") == {:declared, "cards.node"}
    end

    # sabotage: had `expand/3` run for a `list` entry too, so a declared
    # `item_type` contributed element paths - the `order` assertion went red
    # and decision 7's "a list contributes itself alone" would have been
    # broken (verified).
    test "a list entry's item_type may name a declaration and still expands nothing" do
      index =
        typed([%{"path" => "txns", "type" => "list", "item_type" => "cards.credit_txn"}])

      assert index.order == ["txns"]
      assert {:ok, %{item_type: {:declared, "cards.credit_txn"}}} = Index.fetch(index, "txns")
      assert Index.path_types(index) == %{}
    end

    # sabotage: put the expansion ahead of the entry's own `fields` in
    # `entry/4` - this assertion went red, and a path a host wrote out
    # explicitly would have lost to the one derived from the declaration
    # (verified).
    test "an entry that names a declaration and carries fields contributes both, its own first" do
      index =
        typed([
          %{
            "path" => "txn",
            "type" => "cards.credit_txn",
            "fields" => [
              %{"path" => "txn.amount_cents", "type" => "string", "label" => "Written out"},
              %{"path" => "txn.reference", "type" => "string"}
            ]
          }
        ])

      assert index.order == [
               "txn",
               "txn.amount_cents",
               "txn.reference",
               "txn.card",
               "txn.card.brand",
               "txn.risk_reasons"
             ]

      assert {:ok, %{type: :string, label: "Written out"}} =
               Index.fetch(index, "txn.amount_cents")
    end

    # sabotage: dropped `declarations:` from the struct `index/1` builds, so
    # the index carried `%{}` - the declaration assertions went red
    # (verified).
    test "the projections and the completion query see the expanded paths" do
      index = typed([%{"path" => "txn", "type" => "cards.credit_txn"}])

      assert Index.declared_paths(index) ==
               MapSet.new([
                 "txn",
                 "txn.amount_cents",
                 "txn.card",
                 "txn.card.brand",
                 "txn.risk_reasons"
               ])

      assert index |> Index.under("txn.card") |> Enum.map(& &1.path) == ["txn.card.brand"]
      assert Map.keys(index.declarations) |> Enum.sort() == ["cards.card", "cards.credit_txn"]
    end

    # sabotage: gave `scalar_kind/1` a `{:declared, _}` clause answering
    # `:string` - the map gained "txn" and "txn.card", so this test and the
    # list-entry one both went red (verified).
    test "decision 11 inherits: the members project, the declaration-typed entry does not" do
      index = typed([%{"path" => "txn", "type" => "cards.credit_txn"}])

      assert Index.path_types(index) == %{
               "txn.amount_cents" => :number,
               "txn.card.brand" => {:one_of, ["visa", "mastercard", "amex"]},
               "txn.risk_reasons" => {:list, :string}
             }
    end
  end

  describe "the lookups" do
    # sabotage: had `fetch/2` fall back to `{:ok, %{}}` for an unknown path
    # - the `:error` assertion went red, and an unknown path would have
    # answered as though it were declared (verified).
    test "an undeclared path is unknown: :error, nil type, and not declared" do
      index = worked()

      assert Index.fetch(index, "card.number") == :error
      assert Index.type(index, "card.number") == nil
      assert Index.declared?(index, "card.number") == false
      assert Index.declared?(index, "card.brand") == true
      assert Index.type(index, "card.brand") == :string
    end

    # sabotage: had `fetch/2`'s non-binary clause answer `{:ok, %{}}`, so a
    # nil or atom path reported as declared rather than as unknown - these
    # went red (verified).
    test "a path that is not a string is simply not declared" do
      index = worked()

      assert Index.fetch(index, nil) == :error
      assert Index.fetch(index, :card) == :error
      assert Index.declared?(index, 42) == false
      assert Index.type(index, nil) == nil
    end

    # sabotage: matched `under/2` on `String.starts_with?(path, prefix)`
    # without the dot, so `cardholder` answered as being under `card` - the
    # list comparison went red (verified).
    test "under/2 returns the strict descendants in document order" do
      index =
        Index.index(
          document([
            %{"path" => "card", "type" => "object", "fields" => [%{"path" => "card.brand"}]},
            %{"path" => "cardholder"}
          ])
        )

      assert index |> Index.under("card") |> Enum.map(& &1.path) == ["card.brand"]
      assert Index.under(index, "card.brand") == []
      assert Index.under(index, "") == []
      assert Index.under(index, nil) == []
    end

    # sabotage: built `entries/1` from `Map.values/1` instead of from
    # `order` - the ordering assertion went red on the map's own key order
    # (verified).
    test "entries/1 is every entry in document order, depth-first" do
      assert worked() |> Index.entries() |> Enum.map(& &1.path) == @worked_paths
    end
  end

  describe "sensitive_paths/1 and datamodel/1" do
    # sabotage: read the flag as `Map.get(raw, "sensitive?")` truthiness, so
    # a `"sensitive?" => "no"` entry counted as sensitive - the
    # not-sensitive assertion went red (verified).
    test "only an entry the document flags true is sensitive, read literally per entry" do
      index = Index.index(sensitive_document())

      assert Index.sensitive_paths(index) == MapSet.new(["card.number", "processor"])

      not_a_flag = Index.index(document([%{"path" => "a", "sensitive?" => "no"}]))
      assert Index.sensitive_paths(not_a_flag) == MapSet.new([])
    end

    # sabotage: had `declared_paths/1` filter out the sensitive entries -
    # `card.number` left the declared set and this went red, which is
    # decision 7's "the projection deliberately drops it" read backwards
    # (verified).
    test "the declared-path set carries sensitive paths like any other" do
      index = Index.index(sensitive_document())

      assert Index.declared_paths(index) ==
               MapSet.new(["card.token_id", "card.number", "processor", "processor.api_key"])
    end

    # sabotage: swapped the two keys in `datamodel/1` - a consuming pass
    # would have refused every declared path, and this went red (verified).
    test "datamodel/1 pairs both projections in one map" do
      supplied = Index.datamodel(Index.index(sensitive_document()))

      assert supplied.declared ==
               MapSet.new(["card.token_id", "card.number", "processor", "processor.api_key"])

      assert supplied.sensitive == MapSet.new(["card.number", "processor"])
    end
  end

  describe "path_types/1 - ADR-0001 decision 11" do
    # The inline shape arm (ADR-0001 amended 2026-09-06, (c) and (g)) leaves
    # decision 11 alone in both its input and its output: there is no
    # document spelling for an inline shape, so an entry whose `type` is a
    # map is unknown, and the path is absent from the value kinds on the same
    # fall-through row that makes an `object` absent.
    #
    # sabotage: had the entry-type reader answer `:object` for a map instead
    # of leaving it unknown - `Index.type/2` answered `:object` and this went
    # red (verified).
    test "an entry whose type is a map contributes no type and no value kind" do
      index =
        Index.index(%{
          "version" => 1,
          "scopes" => [
            %{
              "scope" => "local",
              "label" => "Local",
              "entries" => [
                %{
                  "name" => "envelope",
                  "path" => "envelope",
                  "label" => "Envelope",
                  "type" => %{"index" => "integer", "status" => "string"}
                },
                %{
                  "name" => "amount_cents",
                  "path" => "amount_cents",
                  "label" => "Amount",
                  "type" => "integer"
                }
              ]
            }
          ]
        })

      assert Index.type(index, "envelope") == nil
      assert Index.path_types(index) == %{"amount_cents" => :number}
    end

    # The record states the answer for its own worked shape, so this is the
    # record's arithmetic pinned rather than the implementation's: "Value
    # kinds (decision 11): amount_cents => :number, card.brand => {:one_of,
    # [...]}, card.last4 => :string, card.expires_on => :date,
    # limits.authorization_window => :duration, risk_reasons => {:list,
    # :string}, event.name => :string; limits and card are absent, being
    # objects."
    #
    # sabotage: had `scalar_kind(:integer)` answer `:integer`, the document's
    # own spelling rather than the expression language's - this test, four of
    # its siblings and the `path_types/1` doctest went red, six failures in
    # all, and every one of them on an `amount_cents`-shaped row (verified).
    test "the record's worked shape projects to exactly the map it lists" do
      assert Index.path_types(worked()) == %{
               "limits.authorization_window" => :duration,
               "amount_cents" => :number,
               "risk_reasons" => {:list, :string},
               "card.brand" => {:one_of, ["visa", "mastercard", "amex"]},
               "card.last4" => :string,
               "card.expires_on" => :date,
               "event.name" => :string
             }
    end

    # The same assertion read the other way: the two object paths of the
    # worked shape are in the declared-path set and not in this map, which
    # is the difference between decision 7's projection and decision 11's.
    #
    # sabotage: gave `scalar_kind(:object)` the answer `:object` - both paths
    # appeared in the map and this test, three siblings and the doctest went
    # red, five failures in all (verified).
    test "an object path is absent, while staying a declared path" do
      types = Index.path_types(worked())

      refute Map.has_key?(types, "limits")
      refute Map.has_key?(types, "card")
      assert MapSet.member?(Index.declared_paths(worked()), "limits")
      assert MapSet.member?(Index.declared_paths(worked()), "card")
    end

    # sabotage: dropped `drawable/1`'s filter so any non-empty `one_of` won -
    # the map and tuple rows below turned into `{:one_of, ...}` and this test
    # alone went red, which is the row it is here to hold (verified).
    test "a one_of holding only undrawable values falls back to the kind" do
      types =
        Index.path_types(
          Index.index(
            document([
              %{"path" => "shaped", "type" => "string", "one_of" => [%{"a" => 1}]},
              %{"path" => "tupled", "type" => "integer", "one_of" => [[1, 2]]},
              %{"path" => "empty", "type" => "boolean", "one_of" => []},
              %{"path" => "malformed", "type" => "date", "one_of" => "visa"}
            ])
          )
        )

      assert types == %{
               "shaped" => :string,
               "tupled" => :number,
               "empty" => :boolean,
               "malformed" => :date
             }
    end

    # An entry that would be absent on its type alone is present when it
    # carries a drawable enumeration: decision 11's row is "any entry
    # carrying a drawable one_of", and the enumeration wins over the kind
    # rather than over the presence of a kind.
    # sabotage: made the kind win instead, with the enumeration only
    # answering where there was no kind - `shipping` kept its values and the
    # other three lost theirs; this test, the worked shape and the doctest
    # went red, three failures in all (verified).
    test "a drawable one_of wins over the kind, including where there is none" do
      types =
        Index.path_types(
          Index.index(
            document([
              %{"path" => "brand", "type" => "string", "one_of" => ["visa", "amex"]},
              %{"path" => "tier", "type" => "integer", "one_of" => [1, 2, 3]},
              %{"path" => "consented", "type" => "boolean", "one_of" => [true, false]},
              %{"path" => "shipping", "type" => "object", "one_of" => ["home", "work"]}
            ])
          )
        )

      assert types == %{
               "brand" => {:one_of, ["visa", "amex"]},
               "tier" => {:one_of, [1, 2, 3]},
               "consented" => {:one_of, [true, false]},
               "shipping" => {:one_of, ["home", "work"]}
             }
    end

    # sabotage: had `scalar_kind(:decimal)` answer `:decimal` - this test alone
    # went red, on the `price` row, with `count` still `:number` beside it
    # (verified).
    test "integer and decimal are both :number, and the rest are themselves" do
      types =
        Index.path_types(
          Index.index(
            document([
              %{"path" => "note", "type" => "string"},
              %{"path" => "count", "type" => "integer"},
              %{"path" => "price", "type" => "decimal"},
              %{"path" => "captured?", "type" => "boolean"},
              %{"path" => "expires_on", "type" => "date"},
              %{"path" => "authorized_at", "type" => "datetime"},
              %{"path" => "window", "type" => "duration"}
            ])
          )
        )

      assert types == %{
               "note" => :string,
               "count" => :number,
               "price" => :number,
               "captured?" => :boolean,
               "expires_on" => :date,
               "authorized_at" => :datetime,
               "window" => :duration
             }
    end

    # sabotage: made `wrap/1` answer `{:list, nil}` instead of `nil` - the four
    # absent rows appeared as lists of nothing and this test alone went red
    # (verified).
    test "a list is {:list, kind} only when its item_type names a kind" do
      types =
        Index.path_types(
          Index.index(
            document([
              %{"path" => "reasons", "type" => "list", "item_type" => "string"},
              %{"path" => "amounts", "type" => "list", "item_type" => "integer"},
              %{"path" => "untyped", "type" => "list"},
              %{"path" => "of_objects", "type" => "list", "item_type" => "object"},
              %{"path" => "of_lists", "type" => "list", "item_type" => "list"},
              %{"path" => "unnameable", "type" => "list", "item_type" => "money"}
            ])
          )
        )

      assert types == %{"reasons" => {:list, :string}, "amounts" => {:list, :number}}
    end

    # A type outside the closed set is already `nil` by the time this
    # projection sees it, and `nil` is absent for the same reason an object
    # is: absence means unknown, never wrong.
    # sabotage: had `scalar_kind/1`'s catch-all answer `:string` rather than
    # `nil` - `money` and the untyped entry appeared as strings, and this
    # test, three siblings and the doctest went red (verified).
    test "an entry whose type is outside the closed set is absent" do
      types =
        Index.path_types(
          Index.index(
            document([
              %{"path" => "money", "type" => "money"},
              %{"path" => "untyped"},
              %{"path" => "note", "type" => "string"}
            ])
          )
        )

      assert types == %{"note" => :string}
    end

    # sabotage: dropped the catch-all clause - `path_types(nil)` raised a
    # FunctionClauseError instead of answering, and this test and the doctest
    # that pins it went red (verified).
    test "total: anything that is not an index projects to the empty map" do
      assert Index.path_types(nil) == %{}
      assert Index.path_types(Index.index(["card.brand"])) == %{}
      assert Index.path_types(%{}) == %{}
      assert Index.path_types("card.brand") == %{}
      assert Index.path_types(Index.index(%{"scopes" => []})) == %{}
    end

    # The vocabulary is the expression language's, not this document's: a
    # kind this projection emits that predicator does not name would be a
    # map an editor could not read. Nine types in, seven atoms out.
    # sabotage: renamed `:duration`'s answer to `:interval`, a kind the
    # expression language does not have - this test, the worked shape and the
    # kind-by-kind row went red, which is the point: a map an editor could
    # not read fails here and not only where the record spells the atom
    # (verified).
    test "every kind emitted is one the expression language names" do
      vocabulary = [:string, :number, :boolean, :date, :datetime, :duration, :list]

      kinds =
        @worked_document
        |> Index.index()
        |> Index.path_types()
        |> Map.values()
        |> Enum.flat_map(fn
          {:one_of, _values} -> []
          {:list, kind} -> [:list, kind]
          kind -> [kind]
        end)

      assert kinds != []
      assert Enum.all?(kinds, &(&1 in vocabulary))
    end
  end
end
