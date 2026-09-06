defmodule StatifierDatamodel.TypesTest do
  @moduledoc """
  ADR-0001 decision 8 - the read check - and the type-expression grammar it
  is decided over.

  The record's worked shape carries the pair the decision is argued on:
  `cards.credit_txn` covers `Settleable` and does not cover `Refundable`.
  Both are transcribed from the record below and the two assertions are the
  record's own arithmetic, not the implementation's.
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
end
