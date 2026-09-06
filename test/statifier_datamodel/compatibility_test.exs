defmodule StatifierDatamodel.CompatibilityTest do
  @moduledoc """
  ADR-0001 decision 9 - what a redefined declaration takes away.

  The record's six rows - decision 9 as amended 2026-09-06 - are pinned
  twice: once row by row, and once as the whole table in a single
  comparison, so a change to the verdict of any one row goes red in a test
  that names it. The two rows the amendment removed are pinned too, as the
  hint they now are. The declarations are the record's worked shape,
  redefined the way a host redefines one.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Compatibility

  alias StatifierDatamodel.Compatibility
  alias StatifierDatamodel.Declarations

  defp declarations(types) do
    Declarations.from_document(%{"version" => 1, "scopes" => [], "types" => types})
  end

  # One declaration named `cards.card`, carrying exactly the fields given.
  defp card(fields) do
    [%{"name" => "cards.card", "kind" => "record", "label" => "Card", "fields" => fields}]
  end

  defp redefined(was, now) do
    {:ok, old} = Declarations.fetch(declarations(card(was)), "cards.card")
    {:ok, new} = Declarations.fetch(declarations(card(now)), "cards.card")
    Compatibility.breaks(old, new)
  end

  @brand %{"name" => "brand", "type" => "string", "required?" => true}
  @last4 %{"name" => "last4", "type" => "string"}

  describe "the five breaking rows" do
    # sabotage: dropped the `:error` clause of the `Map.fetch/2` case in
    # `narrowings/2`, so a field the new declaration does not carry produced
    # no break - the assertion went red and a removed field would have read
    # as compatible (verified).
    test "row 1: a field removed" do
      assert redefined([@brand, @last4], [@brand]) == [{:field_removed, "last4"}]
    end

    # sabotage: compared `was.name` instead of `was.type` in `changes/2`, so
    # a retyped field produced nothing - the assertion went red (verified).
    test "row 2: a field's type changed" do
      now = %{"name" => "last4", "type" => "integer"}
      assert redefined([@last4], [now]) == [{:type_changed, "last4"}]
    end

    # sabotage: reversed the guard to `was.required? and not now.required?` -
    # this row and row 7 both went red, which is the pair the guard's
    # direction decides between (verified).
    test "row 3: a field optional -> required" do
      now = %{"name" => "last4", "type" => "string", "required?" => true}
      assert redefined([@last4], [now]) == [{:made_required, "last4"}]
    end

    # sabotage: dropped the `field.required?` filter from the `added`
    # comprehension, so an optional new field reported `:required_added`
    # too - row 6 went red while this one stayed green, which is the pair
    # that makes the row mean something (verified).
    test "row 4: a required field added" do
      now = %{"name" => "expires_on", "type" => "date", "required?" => true}
      assert redefined([@brand], [@brand, now]) == [{:required_added, "expires_on"}]
    end

    # sabotage: reversed the guard to `not was.required? and now.required?` -
    # this row and row 3 both went red, which is the pair the guard's
    # direction decides between (verified).
    test "row 5: a field required -> optional" do
      now = %{"name" => "brand", "type" => "string"}
      assert redefined([@brand], [now]) == [{:made_optional, "brand"}]
    end
  end

  describe "the one compatible row" do
    # sabotage: had the `added` comprehension emit for every new field - this
    # assertion went red, and every widened document would have been called
    # breaking (verified).
    test "row 6: an optional field added" do
      assert redefined([@brand], [@brand, @last4]) == []
    end
  end

  describe "a one_of is a completion hint, and never a break" do
    # sabotage: added `if was.one_of != now.one_of, do: [{:type_changed,
    # was.name}]` back into `changes/2` - both tests in this describe went
    # red, and a suggestion list would have been reported as a narrowing
    # again (verified).
    test "adding, removing, reordering, widening and shrinking one are all compatible" do
      unconstrained = %{"name" => "brand", "type" => "string"}
      constrained = %{"name" => "brand", "type" => "string", "one_of" => ["visa", "amex"]}
      reordered = %{"name" => "brand", "type" => "string", "one_of" => ["amex", "visa"]}
      widened = %{"name" => "brand", "type" => "string", "one_of" => ["visa", "amex", "discover"]}
      shrunk = %{"name" => "brand", "type" => "string", "one_of" => ["visa"]}
      disjoint = %{"name" => "brand", "type" => "string", "one_of" => ["discover"]}
      emptied = %{"name" => "brand", "type" => "string", "one_of" => []}

      for {change, was, now} <- [
            {"added", unconstrained, constrained},
            {"removed", constrained, unconstrained},
            {"reordered", constrained, reordered},
            {"widened", constrained, widened},
            {"shrunk", constrained, shrunk},
            {"replaced", constrained, disjoint},
            {"emptied", constrained, emptied},
            {"filled from empty", emptied, constrained}
          ] do
        assert {change, redefined([was], [now])} == {change, []}
      end
    end

    # sabotage: had `changes/2` skip `made_optional` when a `one_of` was
    # present - this assertion went red, which is what says the hint is
    # ignored rather than merely never reported on its own (verified).
    test "a hint edited beside a real narrowing does not change what is reported" do
      was = %{"name" => "brand", "type" => "string", "required?" => true, "one_of" => ["visa"]}
      now = %{"name" => "brand", "type" => "string", "one_of" => ["amex", "discover"]}

      assert redefined([was], [now]) == [{:made_optional, "brand"}]
    end
  end

  describe "the table as a whole" do
    # sabotage: dropped the `added` narrowings from the answer, so a
    # required field added reported nothing - the six-row comparison went
    # red on that row, which is the drift a verdict table catches whichever
    # row it reaches (verified).
    test "six rows, six verdicts" do
      optional = %{"name" => "f", "type" => "string"}
      required = %{"name" => "f", "type" => "string", "required?" => true}
      retyped = %{"name" => "f", "type" => "integer"}
      other = %{"name" => "g", "type" => "string"}
      other_required = %{"name" => "g", "type" => "string", "required?" => true}

      rows = [
        {"a field removed", [optional, other], [optional]},
        {"a field's type changed", [optional], [retyped]},
        {"a field optional -> required", [optional], [required]},
        {"a required field added", [optional], [optional, other_required]},
        {"a field required -> optional", [required], [optional]},
        {"an optional field added", [optional], [optional, other]}
      ]

      verdicts =
        for {row, was, now} <- rows do
          {row, if(redefined(was, now) == [], do: :compatible, else: :breaking)}
        end

      assert verdicts == [
               {"a field removed", :breaking},
               {"a field's type changed", :breaking},
               {"a field optional -> required", :breaking},
               {"a required field added", :breaking},
               {"a field required -> optional", :breaking},
               {"an optional field added", :compatible}
             ]
    end
  end

  describe "the answer itself" do
    # sabotage: sorted by reason before name - the assertion went red, and
    # two runs over the same pair would still have agreed, which is why the
    # order is asserted and not merely relied on (verified).
    test "breaks are ordered by field name, then by reason" do
      was = [
        %{"name" => "zulu", "type" => "string"},
        %{"name" => "alpha", "type" => "string", "required?" => true},
        %{"name" => "mike", "type" => "string"}
      ]

      now = [
        %{"name" => "alpha", "type" => "integer"},
        %{"name" => "mike", "type" => "string"}
      ]

      assert redefined(was, now) == [
               {:type_changed, "alpha"},
               {:made_optional, "alpha"},
               {:field_removed, "zulu"}
             ]
    end

    # sabotage: returned `[]` for a pair of `nil`s instead of `:error` - the
    # assertion went red, and *nothing was redefined* would have been
    # reported as *the redefinition is compatible* (verified).
    test "a name declared on neither side is an error, never an empty list" do
      assert Compatibility.breaks(nil, nil) == :error
      assert Compatibility.breaks(%{}, nil) == :error
      assert Compatibility.breaks("cards.card", "cards.card") == :error
    end

    # sabotage: had the `nil` arms of `fields/1` raise instead of answering
    # `[]` - both assertions went red, and a declaration that went away
    # would have had no answer (verified).
    test "a declaration that went away removes its fields; one that appeared adds its required" do
      {:ok, card} = Declarations.fetch(declarations(card([@brand, @last4])), "cards.card")

      assert Compatibility.breaks(card, nil) == [
               {:field_removed, "brand"},
               {:field_removed, "last4"}
             ]

      assert Compatibility.breaks(nil, card) == [{:required_added, "brand"}]
    end

    # sabotage: compared `item_type` alongside `type` in `changes/2` - this
    # assertion went red, and the package would have narrowed `list` in a
    # place decision 8 deliberately does not (verified).
    test "item_type, label and kind are not among the record's five" do
      was = [%{"name" => "risk_reasons", "type" => "list", "item_type" => "string"}]
      now = [%{"name" => "risk_reasons", "type" => "list", "item_type" => "integer"}]

      assert redefined(was, now) == []

      {:ok, record} = Declarations.fetch(declarations(card([@brand])), "cards.card")

      shape =
        declarations([
          %{"name" => "cards.card", "kind" => "shape", "label" => "Card", "fields" => [@brand]}
        ])

      {:ok, as_shape} = Declarations.fetch(shape, "cards.card")

      assert Compatibility.breaks(record, as_shape) == []
    end

    # sabotage: removed `declaration/1`'s catch-all clause, so an input
    # that is not a declaration raised a `FunctionClauseError` instead of
    # being read as not declared on that side - this test went red
    # (verified).
    test "a half-written declaration declares nothing rather than raising" do
      half_written = %{"name" => "cards.card", "kind" => "wishful", "fields" => [@brand]}
      indexed = declarations([half_written])

      # The index drops it, which is where *declares nothing* is decided.
      assert indexed == %{}
      assert Declarations.fetch(indexed, "cards.card") == :error

      # So the pair a caller hands here is `nil` on that side, and the two
      # of them are a name declared on neither.
      assert Compatibility.breaks(nil, nil) == :error

      # A raw document map handed in directly is read as *not declared on
      # that side* rather than raised on.
      assert Compatibility.breaks(half_written, half_written) == :error
    end
  end
end
