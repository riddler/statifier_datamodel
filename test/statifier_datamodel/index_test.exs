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
end
