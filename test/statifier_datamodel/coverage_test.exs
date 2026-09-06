defmodule StatifierDatamodel.CoverageTest do
  @moduledoc """
  ADR-0001 decision 10 - which required fields of a shape a map does not
  fill.

  The shapes are the record's worked shape, `Settleable` and `Refundable`,
  and the maps are the kind of thing a host hands in: some keys present,
  some `nil`, some spelled a way the document does not declare.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Coverage

  alias StatifierDatamodel.Coverage
  alias StatifierDatamodel.Declarations

  @document %{
    "version" => 1,
    "scopes" => [],
    "types" => [
      %{
        "name" => "Settleable",
        "kind" => "shape",
        "label" => "Settleable",
        "fields" => [
          %{"name" => "amount_cents", "type" => "integer", "required?" => true},
          %{"name" => "currency", "type" => "string", "required?" => true},
          %{"name" => "authorized_at", "type" => "datetime", "required?" => true},
          %{"name" => "note", "type" => "string"}
        ]
      },
      %{
        "name" => "cards.credit_txn",
        "kind" => "record",
        "label" => "Credit transaction",
        "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]
      },
      %{
        "name" => "Empty",
        "kind" => "shape",
        "label" => "Empty",
        "fields" => [%{"name" => "note", "type" => "string"}]
      }
    ]
  }

  defp declarations, do: Declarations.from_document(@document)

  describe "missing/3" do
    # sabotage: dropped the `field.required?` filter from the comprehension,
    # so the optional `note` was named as missing - the `{:ok, []}`
    # assertion went red (verified).
    test "a map filling every required field misses nothing" do
      filled = %{
        "amount_cents" => 1250,
        "currency" => "USD",
        "authorized_at" => "2026-09-06T02:00:00Z"
      }

      assert Coverage.missing(declarations(), "Settleable", filled) == {:ok, []}

      assert Coverage.missing(declarations(), "Settleable", Map.put(filled, "note", nil)) ==
               {:ok, []}
    end

    # sabotage: built the answer with `Enum.sort/1`, so the names came back
    # alphabetically - the assertion went red, and a pane would have
    # rendered them in an order the shape does not have (verified).
    test "the names come back in declaration order, not alphabetically" do
      assert Coverage.missing(declarations(), "Settleable", %{}) ==
               {:ok, ["amount_cents", "currency", "authorized_at"]}
    end

    # sabotage: made `filled?/2` answer `Map.has_key?/2` - the `nil`
    # assertion went red, and a key a host wrote as absent-but-present
    # would have counted as filled (verified).
    test "fill is presence with a non-nil value" do
      assert Coverage.missing(declarations(), "Settleable", %{
               "amount_cents" => nil,
               "currency" => "",
               "authorized_at" => false
             }) == {:ok, ["amount_cents"]}
    end

    # sabotage: read the map with `String.to_atom(name)` as a fallback - the
    # assertion went red, and the document's string names would have
    # stopped being the keys it reads (verified).
    test "a key spelled as an atom is not the field's key" do
      assert Coverage.missing(declarations(), "Empty", %{}) == {:ok, []}

      assert Coverage.missing(declarations(), "Settleable", %{
               amount_cents: 1250,
               currency: "USD",
               authorized_at: "2026-09-06T02:00:00Z"
             }) == {:ok, ["amount_cents", "currency", "authorized_at"]}
    end

    # sabotage: replaced the `%{kind: :shape}` match with a bare
    # `{:ok, declaration}`, so a record answered `{:ok, []}` - the record
    # assertion went red, which is decision 10's one hard rule (verified).
    test "a record and an unknown name are both :error, never {:ok, []}" do
      assert Coverage.missing(declarations(), "cards.credit_txn", %{}) == :error
      assert Coverage.missing(declarations(), "Refundable", %{}) == :error
      assert Coverage.missing(declarations(), "", %{}) == :error
      assert Coverage.missing(declarations(), nil, %{}) == :error
      assert Coverage.missing(%{}, "Settleable", %{}) == :error
    end

    # sabotage: dropped the `is_map/1` guard's companion clause from
    # `filled?/2` - the call raised instead of answering, and the assertion
    # went red (verified).
    test "an input that is not a map fills nothing rather than raising" do
      assert Coverage.missing(declarations(), "Settleable", nil) ==
               {:ok, ["amount_cents", "currency", "authorized_at"]}

      assert Coverage.missing(declarations(), "Settleable", ["amount_cents"]) ==
               {:ok, ["amount_cents", "currency", "authorized_at"]}
    end

    # sabotage: made `Declarations`' unnamed-field clause index the field
    # under a `nil` name instead of dropping it - the
    # `{:ok, ["amount_cents"]}` assertion went red on a `nil` in the list,
    # which no map can fill (verified).
    test "a half-written declaration declares nothing, and an unnamed field is not missing" do
      half_written =
        Declarations.from_document(%{
          "types" => [
            %{"name" => "Halfway", "kind" => "wishful", "fields" => []},
            %{
              "name" => "Settleable",
              "kind" => "shape",
              "fields" => [
                %{"name" => "amount_cents", "type" => "integer", "required?" => true},
                %{"type" => "string", "required?" => true}
              ]
            }
          ]
        })

      assert Coverage.missing(half_written, "Halfway", %{}) == :error
      assert Coverage.missing(half_written, "Settleable", %{}) == {:ok, ["amount_cents"]}
    end
  end
end
