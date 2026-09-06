defmodule StatifierDatamodel.TypesTest do
  @moduledoc """
  ADR-0001 decision 8 - the read check - and the type-expression grammar it
  is decided over.

  The record's worked shape carries the pair the decision is argued on:
  `cards.credit_txn` covers `Settleable` and does not cover `Refundable`.
  Both are transcribed from the record below and the two assertions are the
  record's own arithmetic, not the implementation's. Decision 8 as amended
  2026-09-06 adds a third: the same pair with `authorized_at` optional on the
  record no longer covers, and names that field the way an absent one is
  named.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Types

  alias StatifierDatamodel.Declarations
  alias StatifierDatamodel.Index
  alias StatifierDatamodel.Types

  # ADR-0001's "Worked shape", `types` key, transcribed.
  @worked_document %{
    "version" => 1,
    "scopes" => [],
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

  @nine ~w(string integer decimal boolean datetime duration date object list)

  defp worked, do: Declarations.from_document(@worked_document)

  defp declarations(types) do
    Declarations.from_document(%{"version" => 1, "scopes" => [], "types" => types})
  end

  # The worked shape with one of `cards.credit_txn`'s fields made optional,
  # which is the case decision 8's amendment is argued on: the document still
  # declares the field, and no longer promises it.
  defp worked_with_optional(field_name) do
    types =
      Enum.map(@worked_document["types"], fn
        %{"name" => "cards.credit_txn", "fields" => fields} = declaration ->
          %{
            declaration
            | "fields" =>
                Enum.map(fields, fn
                  %{"name" => ^field_name} = field -> Map.delete(field, "required?")
                  field -> field
                end)
          }

        declaration ->
          declaration
      end)

    Declarations.from_document(%{@worked_document | "types" => types})
  end

  describe "the type expression grammar" do
    # sabotage: dropped `"date"` from the closed set in `scalar/1` - the
    # nine-way comparison went red on `date` alone, which is decision 4's
    # one widening (verified).
    test "the nine the record closes the set at parse to themselves" do
      declarations = worked()

      assert Enum.map(@nine, &Types.parse(declarations, &1)) ==
               [
                 :string,
                 :integer,
                 :decimal,
                 :boolean,
                 :datetime,
                 :duration,
                 :date,
                 :object,
                 :list
               ]
    end

    # sabotage: made the index's closed set and the grammar's disagree by
    # removing `"date"` from the index's map alone - the pairwise
    # comparison went red, which is the drift this test exists to catch
    # (verified).
    test "the index and the grammar close the set at the same nine spellings" do
      for spelling <- @nine do
        index =
          Index.index(%{
            "scopes" => [
              %{"scope" => "local", "entries" => [%{"path" => "p", "type" => spelling}]}
            ]
          })

        assert Index.type(index, "p") == Types.scalar(spelling),
               "#{spelling} indexes differently from the way it type-checks"
      end

      for outside <- ["geo_point", "float", "any", ""] do
        index =
          Index.index(%{
            "scopes" => [
              %{"scope" => "local", "entries" => [%{"path" => "p", "type" => outside}]}
            ]
          })

        assert Index.type(index, "p") == nil
        assert Types.scalar(outside) == nil
      end
    end

    # sabotage: looked the declarations up before the closed set, so a
    # document declaring a record called `string` shadowed the scalar - the
    # `:string` assertion went red (verified).
    test "the closed set is read first: a declaration cannot shadow a scalar" do
      declarations =
        declarations([%{"name" => "string", "kind" => "record", "fields" => []}])

      assert Types.parse(declarations, "string") == :string
    end

    # sabotage: returned `{:declared, name}` for any string, so an
    # undeclared name claimed to be declared - the `{:opaque, _}`
    # assertions went red (verified).
    test "a string naming neither is opaque, and anything else is unknown" do
      declarations = worked()

      assert Types.parse(declarations, "cards.credit_txn") == {:declared, "cards.credit_txn"}
      assert Types.parse(declarations, "Settleable") == {:declared, "Settleable"}
      assert Types.parse(declarations, "cards.settlement") == {:opaque, "cards.settlement"}
      assert Types.parse(%{}, "cards.credit_txn") == {:opaque, "cards.credit_txn"}

      assert Types.parse(declarations, "") == :unknown
      assert Types.parse(declarations, nil) == :unknown
      assert Types.parse(declarations, :string) == :unknown
      assert Types.parse(declarations, 7) == :unknown
    end

    # sabotage: printed a `{:declared, name}` as `"declared:" <> name` - the
    # round-trip assertion went red, and a pane would have rendered the
    # tuple's tag (verified).
    test "printing is the spelling a document writes, for every arm" do
      declarations = worked()

      assert Types.to_string({:declared, "cards.credit_txn"}) == "cards.credit_txn"
      assert Types.to_string({:opaque, "cards.settlement"}) == "cards.settlement"
      assert Types.to_string(:unknown) == "unknown"

      for spelling <- @nine do
        assert declarations |> Types.parse(spelling) |> Types.to_string() == spelling
      end
    end
  end

  describe "satisfies/3 - ADR-0001 decision 8, in order" do
    # sabotage: made an unknown side fall through to step 4 - both
    # assertions went red, and the package would have refused every path
    # the document does not describe (verified).
    test "step 1: unknown is permissive both ways" do
      declarations = worked()

      assert Types.satisfies(declarations, :unknown, {:declared, "Settleable"}) == :unknown
      assert Types.satisfies(declarations, {:declared, "cards.credit_txn"}, :unknown) == :unknown
      assert Types.satisfies(declarations, :unknown, :unknown) == :unknown
      assert Types.satisfies?(declarations, :unknown, :integer) == true
    end

    # sabotage: resolved a `{:declared, _}` naming nothing declared to
    # itself instead of to unknown, so it reached step 4 - the `:unknown`
    # assertion went red (verified).
    test "a declared name the document does not declare is unknown, not a failure" do
      declarations = worked()

      assert Types.satisfies(declarations, {:declared, "cards.settlement"}, :integer) == :unknown
      assert Types.satisfies(%{}, {:declared, "cards.credit_txn"}, :integer) == :unknown
    end

    # sabotage: dropped the identity clause, so two identical scalars fell
    # to step 4 - every assertion here went red (verified).
    test "step 2: identity, for a declared name, a scalar and an opaque string alike" do
      declarations = worked()

      assert Types.satisfies(declarations, :date, :date) == :identical
      assert Types.satisfies(declarations, :list, :list) == :identical

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "cards.credit_txn"}
             ) == :identical

      assert Types.satisfies(declarations, {:opaque, "Money"}, {:opaque, "Money"}) == :identical
    end

    # sabotage: had the opaque arm compare by `String.downcase/1`, so
    # `"money"` satisfied `"Money"` - the `:not_assignable` assertion went
    # red, and an opaque string would have stopped comparing by identity
    # alone (verified).
    test "an opaque string is untouched: it compares by identity and by nothing else" do
      declarations = worked()

      assert Types.satisfies(declarations, {:opaque, "Money"}, {:opaque, "money"}) ==
               :not_assignable

      assert Types.satisfies(declarations, {:opaque, "Settleable"}, {:declared, "Settleable"}) ==
               :not_assignable

      assert Types.satisfies(declarations, {:opaque, "Money"}, :integer) == :not_assignable
      assert Types.parse(%{}, "Money") == {:opaque, "Money"}
    end

    # sabotage: looked the covering field up in an empty map rather than in
    # the record's fields, so a record covered nothing - the `:covers`
    # assertion went red (verified).
    test "step 3: the record's worked pair - cards.credit_txn covers Settleable" do
      declarations = worked()

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == :covers

      assert Types.satisfies?(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == true
    end

    # sabotage: returned `:not_assignable` instead of naming the fields, so
    # a consumer could not render which field was missing - the
    # `{:missing, _}` assertion went red (verified).
    test "step 3: cards.credit_txn does not cover Refundable, and settled_at is named" do
      declarations = worked()

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Refundable"}
             ) == {:missing, ["settled_at"]}

      assert Types.satisfies?(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Refundable"}
             ) == false
    end

    # sabotage: dropped the `%{required?: false}` clause of `covered?/4`, so
    # the optional field covered again and the `{:missing, _}` assertion went
    # red (verified).
    test "step 3: an optional record field does not cover a required shape field" do
      declarations = worked_with_optional("authorized_at")

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == {:missing, ["authorized_at"]}

      assert Types.satisfies?(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == false

      assert Types.satisfies(worked(), {:declared, "cards.credit_txn"}, {:declared, "Settleable"}) ==
               :covers
    end

    # sabotage: appended a marker to the name of a field the record declares
    # but leaves optional, so the reason told it apart from an absent one and
    # this went red - the amendment's "one reason, and the names list is what
    # a consumer renders" (verified).
    test "absent and present-but-optional are the same reason, named the same way" do
      absent =
        declarations([
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]
          },
          %{
            "name" => "Settleable",
            "kind" => "shape",
            "fields" => [
              %{"name" => "amount_cents", "type" => "integer", "required?" => true},
              %{"name" => "authorized_at", "type" => "datetime", "required?" => true}
            ]
          }
        ])

      optional =
        declarations([
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [
              %{"name" => "amount_cents", "type" => "integer", "required?" => true},
              %{"name" => "authorized_at", "type" => "datetime"}
            ]
          },
          %{
            "name" => "Settleable",
            "kind" => "shape",
            "fields" => [
              %{"name" => "amount_cents", "type" => "integer", "required?" => true},
              %{"name" => "authorized_at", "type" => "datetime", "required?" => true}
            ]
          }
        ])

      reason = {:missing, ["authorized_at"]}

      assert Types.satisfies(absent, {:declared, "cards.credit_txn"}, {:declared, "Settleable"}) ==
               reason

      assert Types.satisfies(optional, {:declared, "cards.credit_txn"}, {:declared, "Settleable"}) ==
               reason
    end

    # sabotage: dropped the `field.required?` filter from the `covers/4`
    # comprehension, so every shape field was consulted and this went red -
    # the amendment narrows one clause and leaves "a field the shape marks
    # optional is not consulted at all" standing (verified).
    test "an optional shape field is still not consulted, whatever the record says" do
      declarations =
        declarations([
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [
              %{"name" => "amount_cents", "type" => "integer", "required?" => true},
              %{"name" => "risk_reasons", "type" => "list", "item_type" => "string"}
            ]
          },
          %{
            "name" => "Settleable",
            "kind" => "shape",
            "fields" => [
              %{"name" => "amount_cents", "type" => "integer", "required?" => true},
              %{"name" => "risk_reasons", "type" => "list"},
              %{"name" => "currency", "type" => "string"}
            ]
          }
        ])

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == :covers
    end

    # sabotage: took a field whose type names a declaration as covering
    # without descending into it, so the nested record's optional field
    # stopped being read and the outer `{:missing, ["card"]}` assertion went
    # red (verified).
    test "the record side's required? is read at every depth of the check" do
      declarations =
        declarations([
          %{
            "name" => "cards.card",
            "kind" => "record",
            "fields" => [%{"name" => "last4", "type" => "string"}]
          },
          %{
            "name" => "CardLike",
            "kind" => "shape",
            "fields" => [%{"name" => "last4", "type" => "string", "required?" => true}]
          },
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [%{"name" => "card", "type" => "cards.card", "required?" => true}]
          },
          %{
            "name" => "Settleable",
            "kind" => "shape",
            "fields" => [%{"name" => "card", "type" => "CardLike", "required?" => true}]
          }
        ])

      assert Types.satisfies(declarations, {:declared, "cards.card"}, {:declared, "CardLike"}) ==
               {:missing, ["last4"]}

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == {:missing, ["card"]}
    end

    # sabotage: collected the missing names with `MapSet.new/1`, losing the
    # shape's order - the ordered list assertion went red (verified).
    test "the missing names come in the shape's own field order" do
      declarations =
        declarations([
          %{"name" => "cards.credit_txn", "kind" => "record", "fields" => []},
          %{
            "name" => "Refundable",
            "kind" => "shape",
            "fields" => [
              %{"name" => "settled_at", "type" => "datetime", "required?" => true},
              %{"name" => "amount_cents", "type" => "integer", "required?" => true},
              %{"name" => "reason", "type" => "string"}
            ]
          }
        ])

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Refundable"}
             ) == {:missing, ["settled_at", "amount_cents"]}
    end

    # sabotage: compared the covering fields by name alone and ignored the
    # type - the mistyped field stopped being reported and this went red,
    # which is the "of the same `name` whose `type` satisfies" half of the
    # rule (verified).
    test "a field of the right name but the wrong type is missing, not covering" do
      declarations =
        declarations([
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [
              %{"name" => "amount_cents", "type" => "string", "required?" => true},
              %{"name" => "currency", "type" => "string", "required?" => true}
            ]
          },
          %{
            "name" => "Settleable",
            "kind" => "shape",
            "fields" => [
              %{"name" => "amount_cents", "type" => "integer", "required?" => true},
              %{"name" => "currency", "type" => "string", "required?" => true}
            ]
          }
        ])

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == {:missing, ["amount_cents"]}
    end

    # sabotage: had a field whose type resolved to `nil` count as not
    # covering - the `:covers` assertion went red, and an unresolvable
    # field type would have been read as wrong rather than as unknown
    # (verified).
    test "a field whose type resolved to nothing is unknown, and covers" do
      declarations =
        declarations([
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [%{"name" => "amount_cents", "type" => "geo_point", "required?" => true}]
          },
          %{
            "name" => "Settleable",
            "kind" => "shape",
            "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]
          }
        ])

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == :covers
    end

    # sabotage: let a required field be covered when the covering field's
    # own type only nested one level - a record whose nested field
    # satisfied by coverage stopped being accepted and this went red
    # (verified).
    test "a covering field's type is decided by this same check, recursively" do
      declarations =
        declarations([
          %{
            "name" => "cards.card",
            "kind" => "record",
            "fields" => [%{"name" => "last4", "type" => "string", "required?" => true}]
          },
          %{
            "name" => "CardLike",
            "kind" => "shape",
            "fields" => [%{"name" => "last4", "type" => "string", "required?" => true}]
          },
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [%{"name" => "card", "type" => "cards.card", "required?" => true}]
          },
          %{
            "name" => "Settleable",
            "kind" => "shape",
            "fields" => [%{"name" => "card", "type" => "CardLike", "required?" => true}]
          }
        ])

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == :covers
    end

    # sabotage: removed the seen-pair guard - a document whose record and
    # shape refer to each other recursed until the process died, and this
    # test hung then failed (verified).
    test "a cycle between declarations decides rather than recurring forever" do
      declarations =
        declarations([
          %{
            "name" => "cards.node",
            "kind" => "record",
            "fields" => [%{"name" => "next", "type" => "cards.node", "required?" => true}]
          },
          %{
            "name" => "NodeLike",
            "kind" => "shape",
            "fields" => [%{"name" => "next", "type" => "NodeLike", "required?" => true}]
          }
        ])

      assert Types.satisfies(declarations, {:declared, "cards.node"}, {:declared, "NodeLike"}) ==
               :covers
    end

    # sabotage: admitted record-into-record when the fields covered - the
    # `:not_assignable` assertion went red, which is the structural
    # widening the record refuses by name (verified).
    test "step 4: a record is never read as another record, however alike" do
      declarations =
        declarations([
          %{
            "name" => "cards.credit_txn",
            "kind" => "record",
            "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]
          },
          %{
            "name" => "cards.debit_txn",
            "kind" => "record",
            "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]
          }
        ])

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "cards.debit_txn"}
             ) == :not_assignable

      assert Types.satisfies?(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "cards.debit_txn"}
             ) == false
    end

    # sabotage: read a shape as a record by dropping the `kind` match in
    # `covers/4` - a shape held at a path satisfied a record, and this went
    # red on the first assertion (verified).
    test "step 4: the widening runs one way only, and only between the two kinds" do
      declarations = worked()

      assert Types.satisfies(
               declarations,
               {:declared, "Settleable"},
               {:declared, "cards.credit_txn"}
             ) == :not_assignable

      assert Types.satisfies(declarations, {:declared, "Settleable"}, {:declared, "Refundable"}) ==
               :not_assignable

      assert Types.satisfies(declarations, :integer, {:declared, "Settleable"}) ==
               :not_assignable

      assert Types.satisfies(declarations, {:declared, "cards.credit_txn"}, :object) ==
               :not_assignable

      assert Types.satisfies(declarations, :integer, :string) == :not_assignable
    end

    # sabotage: dropped the catch-all clause of `resolve/2`, so a term
    # outside the grammar raised a `FunctionClauseError` instead of
    # answering - this went red on the raise, and the check stopped being
    # total (verified).
    test "the check is total: a term outside the grammar is unknown" do
      declarations = worked()

      assert Types.satisfies(declarations, "cards.credit_txn", :integer) == :unknown
      assert Types.satisfies(declarations, nil, :integer) == :unknown
      assert Types.satisfies(declarations, {:declared, 7}, :integer) == :unknown
      assert Types.satisfies(declarations, :integer, %{}) == :unknown
      assert Types.satisfies?(declarations, 42, {:declared, "Settleable"}) == true
    end
  end

  # ADR-0001's amendment of 2026-09-06, worked example: the fan-out envelope
  # the compiler assembles, and the summary the host's document declares.
  @envelope_document %{
    "version" => 1,
    "scopes" => [],
    "types" => [
      %{
        "name" => "ChunkSummary",
        "kind" => "shape",
        "label" => "Chunk summary",
        "fields" => [
          %{"name" => "authorized_count", "type" => "integer", "required?" => true},
          %{"name" => "declined_count", "type" => "integer", "required?" => true}
        ]
      },
      %{
        "name" => "cards.chunk_summary",
        "kind" => "record",
        "label" => "Chunk summary, written back",
        "fields" => [
          %{"name" => "authorized_count", "type" => "integer", "required?" => true},
          %{"name" => "declined_count", "type" => "integer", "required?" => true}
        ]
      }
    ]
  }

  defp envelope_declarations, do: Declarations.from_document(@envelope_document)

  # The record's `chunk_envelope`, transcribed.
  defp summary_members do
    [
      %{name: "authorized_count", type: :integer, required?: true},
      %{name: "declined_count", type: :integer, required?: true}
    ]
  end

  defp chunk_envelope do
    {:shape,
     [
       %{name: "index", type: :integer, required?: true},
       %{name: "status", type: :string, required?: true},
       %{name: "donedata", type: {:shape, summary_members()}, required?: false}
     ]}
  end

  describe "the inline shape arm - ADR-0001 amended 2026-09-06" do
    # sabotage: gave `parse/2` a clause reading a list of maps into an inline
    # shape, which is the document spelling arm (c) refuses - this went red
    # on the list assertion (verified).
    test "a document is never a source of one: parse/2 is unchanged" do
      declarations = envelope_declarations()

      assert Types.parse(declarations, "ChunkSummary") == {:declared, "ChunkSummary"}

      # The only spellings a document can write, and none of them is a shape.
      assert Types.parse(declarations, %{"authorized_count" => "integer"}) == :unknown
      assert Types.parse(declarations, [%{"name" => "authorized_count"}]) == :unknown
      assert Types.parse(declarations, {:shape, summary_members()}) == :unknown
    end

    # sabotage: had `member_to_string/1` drop the `?` it marks an unpromised
    # member with - the envelope's rendering went red (verified).
    test "to_string/1 renders the arm, and renders an unpromised member as one" do
      assert Types.to_string({:shape, summary_members()}) ==
               "{authorized_count: integer, declined_count: integer}"

      assert Types.to_string(chunk_envelope()) ==
               "{index: integer, status: string, " <>
                 "donedata?: {authorized_count: integer, declined_count: integer}}"

      assert Types.to_string({:shape, []}) == "{}"
    end

    # Step 1. Unknown is permissive both ways for the new arm exactly as for
    # every other, and is still decided first.
    # sabotage: had `resolve/2` answer `{:opaque, name}` for a name the
    # document does not declare instead of `:unknown` - the two undeclared
    # reads stopped being permissive and this went red (verified).
    test "step 1: unknown is permissive in both directions" do
      declarations = envelope_declarations()

      assert Types.satisfies(declarations, chunk_envelope(), :unknown) == :unknown
      assert Types.satisfies(declarations, :unknown, chunk_envelope()) == :unknown

      assert Types.satisfies(declarations, chunk_envelope(), {:declared, "Nothing"}) == :unknown
      assert Types.satisfies(declarations, {:declared, "Nothing"}, chunk_envelope()) == :unknown
    end

    # sabotage: dropped the member-set identity check from the two-inline-
    # shapes clause of `decide/4`, leaving it member-wise - the reordered
    # pair answered `:covers` rather than `:identical` (verified).
    test "step 2: identity is member-set-wise, not term equality" do
      declarations = envelope_declarations()

      reordered =
        {:shape,
         [
           %{name: "donedata", type: {:shape, summary_members()}, required?: false},
           %{name: "status", type: :string, required?: true},
           %{name: "index", type: :integer, required?: true}
         ]}

      assert Types.satisfies(declarations, chunk_envelope(), reordered) == :identical
      assert Types.satisfies(declarations, reordered, chunk_envelope()) == :identical

      # ... and a nested inline shape compares the same way its parent does.
      nested_reordered =
        {:shape,
         [
           %{name: "index", type: :integer, required?: true},
           %{name: "status", type: :string, required?: true},
           %{
             name: "donedata",
             type: {:shape, Enum.reverse(summary_members())},
             required?: false
           }
         ]}

      assert Types.satisfies(declarations, chunk_envelope(), nested_reordered) == :identical
    end

    # sabotage: had `covered?/4` answer true without comparing the two member
    # types - the retyped member covered and this went red (verified).
    test "step 2's negative: a member differing in type or in required? is not identity" do
      declarations = envelope_declarations()

      retyped =
        {:shape,
         [
           %{name: "authorized_count", type: :string, required?: true},
           %{name: "declined_count", type: :integer, required?: true}
         ]}

      assert Types.satisfies(declarations, {:shape, summary_members()}, retyped) ==
               {:missing, ["authorized_count"]}

      relaxed =
        {:shape,
         [
           %{name: "authorized_count", type: :integer, required?: false},
           %{name: "declined_count", type: :integer, required?: true}
         ]}

      # Not identical, but the relaxed side asks for less, so it is covered.
      assert Types.satisfies(declarations, {:shape, summary_members()}, relaxed) == :covers

      assert Types.satisfies(declarations, relaxed, {:shape, summary_members()}) ==
               {:missing, ["authorized_count"]}
    end

    # sabotage: made the `{:declared, held}, {:shape, expected}` clause of
    # `decide/4` answer `:not_assignable` outright - the record read against
    # the envelope's inner shape went red (verified).
    test "step 3: a declared record covers an inline shape, member-wise" do
      declarations = envelope_declarations()

      assert Types.satisfies(
               declarations,
               {:declared, "cards.chunk_summary"},
               {:shape, summary_members()}
             ) == :covers

      assert Types.satisfies?(
               declarations,
               {:declared, "cards.chunk_summary"},
               {:shape, summary_members()}
             ) == true
    end

    # sabotage: dropped the `%{required?: false}` clause of `covered?/4` - the
    # record's optional `declined_count` covered the promised member and this
    # went red (verified).
    test "step 3's negative: a record missing a promised member names it" do
      declarations =
        declarations([
          %{
            "name" => "cards.partial",
            "kind" => "record",
            "label" => "Partial",
            "fields" => [
              %{"name" => "authorized_count", "type" => "integer", "required?" => true},
              %{"name" => "declined_count", "type" => "integer"}
            ]
          }
        ])

      assert Types.satisfies(
               declarations,
               {:declared, "cards.partial"},
               {:shape, summary_members()}
             ) == {:missing, ["declined_count"]}
    end

    # sabotage: made the `{:shape, held}, {:declared, expected}` clause of
    # `decide/4` answer `:not_assignable` outright - the summary read against
    # `ChunkSummary` went red (verified).
    test "step 3: an inline shape covers a declared shape, member-wise" do
      declarations = envelope_declarations()

      assert Types.satisfies(
               declarations,
               {:shape, summary_members()},
               {:declared, "ChunkSummary"}
             ) == :covers
    end

    # sabotage: had `member_wise/4` merge a member's nested inline shape into
    # the held side's names, which is the widening this refusal forbids - the
    # envelope covered the summary and this went red (verified).
    test "step 3's negative: the whole envelope does not cover the summary" do
      declarations = envelope_declarations()

      # The record's own refusal: the summary is one member down, and this
      # package widens nothing to find it.
      assert Types.satisfies(declarations, chunk_envelope(), {:declared, "ChunkSummary"}) ==
               {:missing, ["authorized_count", "declined_count"]}
    end

    # sabotage: had two inline shapes answer `:not_assignable` whenever they
    # are not identical, leaving the arm with identity only - the `wider` pair
    # went red (verified).
    test "step 3: two inline shapes compare structurally, and name what is unpromised" do
      declarations = envelope_declarations()

      wider =
        {:shape,
         [
           %{name: "authorized_count", type: :integer, required?: true},
           %{name: "declined_count", type: :integer, required?: true},
           %{name: "settled_at", type: :datetime, required?: false}
         ]}

      assert Types.satisfies(declarations, wider, {:shape, summary_members()}) == :covers

      assert Types.satisfies(declarations, {:shape, summary_members()}, wider) == :covers

      demanding =
        {:shape,
         [
           %{name: "declined_count", type: :integer, required?: true},
           %{name: "settled_at", type: :datetime, required?: true},
           %{name: "authorized_count", type: :integer, required?: true}
         ]}

      # Named in the expected side's own member order, not the held side's.
      assert Types.satisfies(declarations, {:shape, summary_members()}, demanding) ==
               {:missing, ["settled_at"]}
    end

    # sabotage: made the `{:shape, held}, {:declared, expected}` clause answer
    # member-wise for a record too - an inline shape satisfied a declared
    # record and this went red on the first assertion (verified).
    test "the two refusals: nominal identity is untouched" do
      declarations = envelope_declarations()

      # An inline shape has no name to be a record by, however well it fits.
      assert Types.satisfies(
               declarations,
               {:shape, summary_members()},
               {:declared, "cards.chunk_summary"}
             ) == :not_assignable

      # A declared shape held is a constraint, not a fact about what is there.
      assert Types.satisfies(
               declarations,
               {:declared, "ChunkSummary"},
               {:shape, summary_members()}
             ) == :not_assignable

      # And the arm reaches nothing else in the grammar.
      assert Types.satisfies(declarations, {:shape, summary_members()}, :object) ==
               :not_assignable

      assert Types.satisfies(declarations, :object, {:shape, summary_members()}) ==
               :not_assignable

      assert Types.satisfies(declarations, {:shape, summary_members()}, {:opaque, "Summary"}) ==
               :not_assignable
    end

    # sabotage: had `covered?/4` compare two member types by term instead of
    # recursing through `decide/4` - the nested record-against-inline-shape
    # read went red (verified).
    test "a member's type recurses under the same check, to any depth" do
      declarations = envelope_declarations()

      held =
        {:shape,
         [
           %{
             name: "donedata",
             type:
               {:shape,
                [%{name: "inner", type: {:declared, "cards.chunk_summary"}, required?: true}]},
             required?: true
           }
         ]}

      expected =
        {:shape,
         [
           %{
             name: "donedata",
             type:
               {:shape, [%{name: "inner", type: {:shape, summary_members()}, required?: true}]},
             required?: true
           }
         ]}

      assert Types.satisfies(declarations, held, expected) == :covers

      mismatched =
        {:shape,
         [
           %{
             name: "donedata",
             type: {:shape, [%{name: "inner", type: :string, required?: true}]},
             required?: true
           }
         ]}

      assert Types.satisfies(declarations, held, mismatched) == {:missing, ["donedata"]}
    end

    # sabotage: the same term comparison in `covered?/4`, which step 1 never
    # reaches through - both directions went red (verified).
    test "a member whose type is unknown is satisfied both ways" do
      declarations = envelope_declarations()

      loose = {:shape, [%{name: "authorized_count", type: :unknown, required?: true}]}
      strict = {:shape, [%{name: "authorized_count", type: :integer, required?: true}]}

      assert Types.satisfies(declarations, loose, strict) == :covers
      assert Types.satisfies(declarations, strict, loose) == :covers
    end

    # sabotage: dropped the `%{required?: false}` clause of `covered?/4` - an
    # unpromised held member covered a promised expected one and this went
    # red (verified).
    test "decision 8's required?-ness rule applies member-wise" do
      declarations = envelope_declarations()

      unpromised = {:shape, [%{name: "authorized_count", type: :integer, required?: false}]}
      promised = {:shape, [%{name: "authorized_count", type: :integer, required?: true}]}

      assert Types.satisfies(declarations, unpromised, promised) ==
               {:missing, ["authorized_count"]}

      assert Types.satisfies(declarations, promised, unpromised) == :covers
    end

    # sabotage: dropped the `member/2` name guard and the `Enum.uniq_by/2`
    # from `resolve/2`'s inline-shape clause - a repeated name took its last
    # occurrence and an unnamed member became one called `nil`, and this went
    # red (verified).
    test "a malformed member normalizes rather than raising" do
      declarations = envelope_declarations()

      # A repeated name keeps its first occurrence, as a repeated field name
      # does; the second, which does not satisfy, is not consulted, so the
      # normalized shape is the single-member one it is read against.
      repeated =
        {:shape,
         [
           %{name: "authorized_count", type: :integer, required?: true},
           %{name: "authorized_count", type: :string, required?: true}
         ]}

      assert Types.satisfies(
               declarations,
               repeated,
               {:shape, [%{name: "authorized_count", type: :integer, required?: true}]}
             ) == :identical

      # A member without a usable name contributes nothing, on either side.
      unnamed = {:shape, [%{name: "", type: :integer, required?: true}, %{type: :integer}]}

      assert Types.satisfies(declarations, unnamed, {:shape, []}) == :identical

      # A member with no type at all is unknown, which is permissive.
      untyped = {:shape, [%{name: "authorized_count", required?: true}]}

      assert Types.satisfies(
               declarations,
               untyped,
               {:shape, [%{name: "authorized_count", type: :integer, required?: true}]}
             ) == :covers

      # `required?` follows the optional-boolean convention: only `true` is a
      # promise.
      absent_required = {:shape, [%{name: "authorized_count", type: :integer}]}

      assert Types.satisfies(
               declarations,
               absent_required,
               {:shape, [%{name: "authorized_count", type: :integer, required?: true}]}
             ) == {:missing, ["authorized_count"]}

      # And a shape whose members are not a list at all is outside the
      # grammar, which is unknown - the check stays total.
      assert Types.satisfies(declarations, {:shape, :not_a_list}, :integer) == :unknown
    end

    # sabotage: dropped the `kind:` matches from `covers/4`, so any two
    # declarations compared member-wise - `Settleable` held satisfied
    # `cards.credit_txn` and this went red (verified).
    test "a document holding no inline shape answers exactly as it did before" do
      declarations = worked()

      # The whole of decision 8 over the worked shape, unchanged by the arm.
      assert Types.satisfies(declarations, {:declared, "cards.credit_txn"}, :unknown) == :unknown
      assert Types.satisfies(declarations, :date, :date) == :identical

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "cards.credit_txn"}
             ) == :identical

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == :covers

      assert Types.satisfies(
               declarations,
               {:declared, "cards.credit_txn"},
               {:declared, "Refundable"}
             ) == {:missing, ["settled_at"]}

      assert Types.satisfies(
               declarations,
               {:declared, "Settleable"},
               {:declared, "cards.credit_txn"}
             ) == :not_assignable

      assert Types.satisfies(
               worked_with_optional("authorized_at"),
               {:declared, "cards.credit_txn"},
               {:declared, "Settleable"}
             ) == {:missing, ["authorized_at"]}
    end
  end
end
