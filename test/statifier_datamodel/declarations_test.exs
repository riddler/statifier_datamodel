defmodule StatifierDatamodel.DeclarationsTest do
  @moduledoc """
  ADR-0001 decision 5 and decision 6's `types` addition, asserted where the
  reader lives.

  The record's own worked shape carries a `types` key with four
  declarations - two records and two shapes, one of the records referring to
  the other - and it is transcribed below, as the index's tests transcribe
  the scopes half, so the assertions are against the document the record
  publishes rather than against one written to suit them.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Declarations

  alias StatifierDatamodel.Declarations

  # ADR-0001's "Worked shape", `types` key, transcribed.
  @worked_types [
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

  @worked_document %{
    "version" => 1,
    "scopes" => [
      %{
        "scope" => "local",
        "label" => "Chart-local",
        "entries" => [%{"name" => "amount_cents", "path" => "amount_cents", "type" => "integer"}]
      }
    ],
    "types" => @worked_types
  }

  defp worked, do: Declarations.from_document(@worked_document)

  defp document(types) do
    %{"version" => 1, "scopes" => [], "types" => types}
  end

  describe "from_document/1 - the types key" do
    # sabotage: indexed the declarations by `label` instead of by `name` -
    # the key list came back as the four labels and this went red
    # (verified).
    test "the record's worked shape declares its four names, records and shapes alike" do
      declarations = worked()

      assert declarations |> Map.keys() |> Enum.sort() ==
               ["Refundable", "Settleable", "cards.card", "cards.credit_txn"]

      assert {:ok, %{kind: :record, label: "Credit transaction"}} =
               Declarations.fetch(declarations, "cards.credit_txn")

      assert {:ok, %{kind: :shape, label: "Settleable"}} =
               Declarations.fetch(declarations, "Settleable")
    end

    # sabotage: had `from_document/1` return the declarations for any map,
    # so a document with no `types` key raised a `KeyError` out of the
    # match instead of answering `%{}` - this went red on the raise
    # (verified).
    test "a document without a types key declares nothing, and so does a non-document" do
      assert Declarations.from_document(%{"version" => 1, "scopes" => []}) == %{}
      assert Declarations.from_document(%{"scopes" => [], "types" => "cards.card"}) == %{}
      assert Declarations.from_document(%{}) == %{}
      assert Declarations.from_document(["cards.card"]) == %{}
      assert Declarations.from_document(nil) == %{}
      assert Declarations.from_document(42) == %{}
    end

    # sabotage: dropped the `kind` and `fields` guards from
    # `declared_name/1`, so every half-written declaration was indexed - the
    # key comparison went red with four extra names in it (verified).
    test "a half-written declaration declares nothing, and never raises" do
      declarations =
        Declarations.from_document(
          document([
            %{"kind" => "record", "label" => "Nameless", "fields" => []},
            %{"name" => "", "kind" => "record", "fields" => []},
            %{"name" => "cards.no_kind", "label" => "No kind", "fields" => []},
            %{"name" => "cards.bad_kind", "kind" => "struct", "fields" => []},
            %{"name" => "cards.no_fields", "kind" => "record", "label" => "No fields"},
            %{"name" => "cards.string_fields", "kind" => "record", "fields" => "brand"},
            "not a declaration map",
            %{"name" => "cards.card", "kind" => "record", "label" => "Card", "fields" => []}
          ])
        )

      assert Map.keys(declarations) == ["cards.card"]
    end

    # sabotage: dropped a declaration whose `label` was absent - the
    # `cards.card` assertion went red, and the record's own type for a
    # declaration carries `label: String.t() | nil` (verified).
    test "a declaration with no usable label still declares its fields" do
      declarations =
        Declarations.from_document(
          document([
            %{"name" => "cards.card", "kind" => "record", "fields" => [%{"name" => "brand"}]},
            %{"name" => "cards.txn", "kind" => "record", "label" => 7, "fields" => []}
          ])
        )

      assert {:ok, %{label: nil, fields: [%{name: "brand"}]}} =
               Declarations.fetch(declarations, "cards.card")

      assert {:ok, %{label: nil}} = Declarations.fetch(declarations, "cards.txn")
    end

    # sabotage: replaced `Map.put_new/3` with `Map.put/3` in the reduce, so
    # the last declaration of a repeated name won - the label assertion went
    # red (verified).
    test "a repeated name keeps its first occurrence, in list order" do
      declarations =
        Declarations.from_document(
          document([
            %{"name" => "cards.card", "kind" => "record", "label" => "First", "fields" => []},
            %{"name" => "cards.card", "kind" => "shape", "label" => "Second", "fields" => []}
          ])
        )

      assert {:ok, %{kind: :record, label: "First"}} =
               Declarations.fetch(declarations, "cards.card")
    end

    # sabotage: had `fetch/2` answer `{:ok, %{}}` for a name the document
    # does not declare - the `:error` assertions went red, and a consumer
    # would have read an empty declaration as a real one (verified).
    test "fetch/2 answers :error for a name the document does not declare" do
      declarations = worked()

      assert Declarations.fetch(declarations, "cards.settlement") == :error
      assert Declarations.fetch(declarations, nil) == :error
      assert Declarations.fetch(declarations, :"cards.card") == :error
      assert Declarations.fetch(%{}, "cards.card") == :error
    end
  end

  describe "a declaration's fields" do
    # sabotage: built the fields with `Enum.map/2` into a map keyed by name,
    # losing the record's ordering - the field-name list came back sorted
    # and this went red (verified).
    test "fields keep the record's order, with required? defaulting to false" do
      {:ok, txn} = Declarations.fetch(worked(), "cards.credit_txn")

      assert Enum.map(txn.fields, & &1.name) ==
               ["amount_cents", "currency", "card", "authorized_at", "risk_reasons"]

      assert Enum.map(txn.fields, & &1.required?) == [true, true, true, true, false]
    end

    # sabotage: resolved a field's type against the closed set alone, so
    # `cards.card` came back `nil` - the `{:declared, _}` assertion went red
    # and a record could not have named another record (verified).
    test "a field typed by another declared name resolves, in either list order" do
      {:ok, txn} = Declarations.fetch(worked(), "cards.credit_txn")

      assert %{name: "card", type: {:declared, "cards.card"}} =
               Enum.find(txn.fields, &(&1.name == "card"))

      # `cards.card` is declared *after* the record that refers to it, so
      # resolution cannot be a single pass down the list.
      backwards =
        Declarations.from_document(
          document([
            %{
              "name" => "cards.card",
              "kind" => "record",
              "fields" => [%{"name" => "txn", "type" => "cards.credit_txn"}]
            },
            %{"name" => "cards.credit_txn", "kind" => "record", "fields" => []}
          ])
        )

      assert {:ok, %{fields: [%{type: {:declared, "cards.credit_txn"}}]}} =
               Declarations.fetch(backwards, "cards.card")
    end

    # sabotage: carried an unresolvable type string through as
    # `{:declared, name}` - the `nil` assertions went red, and the package
    # would have claimed a declaration the document never made (verified).
    test "a field naming nothing declared and nothing in the closed set is nil" do
      declarations =
        Declarations.from_document(
          document([
            %{
              "name" => "cards.card",
              "kind" => "record",
              "fields" => [
                %{"name" => "brand", "type" => "string"},
                %{"name" => "geo", "type" => "geo_point"},
                %{"name" => "weird", "type" => 7},
                %{"name" => "absent"}
              ]
            }
          ])
        )

      {:ok, card} = Declarations.fetch(declarations, "cards.card")
      by_name = Map.new(card.fields, &{&1.name, &1})

      assert by_name["brand"].type == :string
      assert by_name["geo"].type == nil
      assert by_name["weird"].type == nil
      assert by_name["absent"].type == nil
    end

    # sabotage: read `item_type` with the entry normalizer's rule and
    # dropped it from the field map - the `:string` assertion went red
    # (verified).
    test "a list field carries its item_type under the same resolution rule" do
      {:ok, txn} = Declarations.fetch(worked(), "cards.credit_txn")
      risk_reasons = Enum.find(txn.fields, &(&1.name == "risk_reasons"))

      assert risk_reasons.type == :list
      assert risk_reasons.item_type == :string

      nested =
        Declarations.from_document(
          document([
            %{"name" => "cards.card", "kind" => "record", "fields" => []},
            %{
              "name" => "cards.wallet",
              "kind" => "record",
              "fields" => [%{"name" => "cards", "type" => "list", "item_type" => "cards.card"}]
            }
          ])
        )

      assert {:ok, %{fields: [%{item_type: {:declared, "cards.card"}}]}} =
               Declarations.fetch(nested, "cards.wallet")
    end

    # sabotage: read `required?` by truthiness, so `"required?" => "yes"`
    # counted as required - the `false` assertion went red (verified).
    test "required? is taken only when it is literally true" do
      declarations =
        Declarations.from_document(
          document([
            %{
              "name" => "cards.card",
              "kind" => "record",
              "fields" => [
                %{"name" => "brand", "type" => "string", "required?" => "yes"},
                %{"name" => "last4", "type" => "string", "required?" => true}
              ]
            }
          ])
        )

      {:ok, card} = Declarations.fetch(declarations, "cards.card")
      assert Enum.map(card.fields, & &1.required?) == [false, true]
    end

    # sabotage: kept a field with no usable name, which entered the field
    # list as `%{name: nil}` - the name list went red with a `nil` in it,
    # and a coverage failure could not have named it (verified).
    test "a field with no usable name contributes nothing, and a repeat keeps the first" do
      declarations =
        Declarations.from_document(
          document([
            %{
              "name" => "cards.card",
              "kind" => "record",
              "fields" => [
                %{"type" => "string"},
                %{"name" => "", "type" => "string"},
                %{"name" => 7, "type" => "string"},
                "not a field map",
                %{"name" => "brand", "type" => "string", "label" => "First"},
                %{"name" => "brand", "type" => "integer", "label" => "Second"}
              ]
            }
          ])
        )

      assert {:ok, %{fields: [%{name: "brand", type: :string, label: "First"}]}} =
               Declarations.fetch(declarations, "cards.card")
    end

    # sabotage: read `one_of` with no shape guard, so a string was carried
    # through - the `nil` assertion went red (verified).
    test "the optional keys are taken only in the shape the record gives them" do
      {:ok, txn} = Declarations.fetch(worked(), "cards.credit_txn")
      currency = Enum.find(txn.fields, &(&1.name == "currency"))

      assert currency.one_of == ["USD", "EUR", "GBP"]
      assert currency.label == nil

      declarations =
        Declarations.from_document(
          document([
            %{
              "name" => "signup.step",
              "kind" => "record",
              "fields" => [
                %{"name" => "step", "type" => "string", "label" => "Step", "one_of" => "email"}
              ]
            }
          ])
        )

      assert {:ok, %{fields: [%{label: "Step", one_of: nil}]}} =
               Declarations.fetch(declarations, "signup.step")
    end
  end
end
