defmodule StatifierDatamodel.DocumentTest do
  @moduledoc """
  The document-level reads, asserted against the same distinctions the
  index is: an input that is not a document is not an empty claim, and an
  enumeration nothing can draw is absent rather than empty.
  """

  use ExUnit.Case, async: true

  doctest StatifierDatamodel.Document

  alias StatifierDatamodel.{Document, Index}

  @datamodel_document %{
    "version" => 1,
    "scopes" => [
      %{
        "scope" => "local",
        "entries" => [
          %{
            "path" => "card",
            "type" => "object",
            "fields" => [%{"path" => "card.brand"}, %{"path" => "card.last4"}]
          },
          %{"path" => "cardholder", "type" => "string"}
        ]
      }
    ]
  }

  defp value_datamodel(entries) do
    %{"version" => 1, "scopes" => [%{"scope" => "local", "entries" => entries}]}
  end

  defp step_and_brand do
    value_datamodel([
      %{
        "path" => "signup.step",
        "type" => "string",
        "one_of" => ["details", "payment", "review"]
      },
      %{"path" => "card.brand", "type" => "string", "one_of" => ["visa", "amex"]},
      %{"path" => "signup.email", "type" => "string"}
    ])
  end

  describe "declared_paths/1" do
    # sabotage: removed the `nil ->` arm and returned `Index.declared_paths`
    # unconditionally, which raised a FunctionClauseError on a nil index -
    # this went red on the raise (verified).
    test "a document projects to the same set the index does" do
      assert Document.declared_paths(@datamodel_document) ==
               Index.declared_paths(Index.index(@datamodel_document))

      assert Document.declared_paths(@datamodel_document) ==
               MapSet.new(["card", "card.brand", "card.last4", "cardholder"])
    end

    # sabotage: had the `nil ->` arm return `MapSet.new()` - a shape the
    # index declines became an empty claim rather than no claim, and every
    # assertion but the first went red. That is the distinction decision 6
    # exists for (verified).
    test "an empty document is an empty claim; anything else is no document at all" do
      assert Document.declared_paths(%{"scopes" => []}) == MapSet.new([])
      assert Document.declared_paths(%{"scopes" => "global"}) == nil
      assert Document.declared_paths(%{}) == nil
      assert Document.declared_paths(["a.b"]) == nil
      assert Document.declared_paths(MapSet.new(["a.b"])) == nil
      assert Document.declared_paths(nil) == nil
      assert Document.declared_paths(42) == nil
    end
  end

  describe "candidates_under/2" do
    # sabotage: `under/2` swapped for a `String.starts_with?(&1.path, prefix)`
    # filter without the dot - `cardholder` joins the result and this goes
    # red (verified). That dot is the whole difference between a path
    # segment and a string prefix.
    test "narrows to entries strictly under the prefix, in document order" do
      assert Document.candidates_under(@datamodel_document, "card") ==
               ["card.brand", "card.last4"]
    end

    # sabotage: the `nil ->` arm calling `Index.under(nil, prefix)` instead
    # of returning `[]` - a flat list has no order to query and this raises
    # rather than returning empty (verified).
    test "an input that is not a document has no order to query" do
      assert Document.candidates_under(["card.brand"], "card") == []
      assert Document.candidates_under(nil, "card") == []
      assert Document.candidates_under(@datamodel_document, "") == []
    end
  end

  describe "declared_values/1" do
    # sabotage: `declared_values/1` answering `%{}` for an index it has ->
    # every assertion here goes red. The derivation is the whole of this
    # function.
    test "a path with declared values offers them, in declaration order" do
      assert Document.declared_values(step_and_brand()) == %{
               "signup.step" => ["details", "payment", "review"],
               "card.brand" => ["visa", "amex"]
             }
    end

    # sabotage: mapping an empty option list to `[]` instead of leaving the
    # entry out -> this goes red. An absent key is a free-text control and
    # an empty list is an empty picker, and only a host may write the
    # second.
    test "a path with no declared values is absent, not present and empty" do
      refute Map.has_key?(Document.declared_values(step_and_brand()), "signup.email")
    end

    # sabotage: dropping the number and boolean clauses of `option/1` -> both
    # paths vanish from the map and this goes red.
    test "numbers and booleans are offered as their printed form" do
      candidates =
        Document.declared_values(
          value_datamodel([
            %{"path" => "signup.attempts", "type" => "integer", "one_of" => [1, 2, 3]},
            %{"path" => "signup.consented", "type" => "boolean", "one_of" => [true, false]}
          ])
        )

      assert candidates == %{
               "signup.attempts" => ["1", "2", "3"],
               "signup.consented" => ["true", "false"]
             }
    end

    # sabotage: `option/1` falling through to `inspect/1` instead of dropping
    # -> `["a"]` and `%{"b" => 1}` reach the picker as their inspect forms and
    # this goes red. A value that cannot be drawn as an option is not one.
    test "values with no drawable form are dropped, and a path left with none is absent" do
      candidates =
        Document.declared_values(
          value_datamodel([
            %{"path" => "signup.mixed", "one_of" => ["ok", ["a"], %{"b" => 1}, nil]},
            %{"path" => "signup.undrawable", "one_of" => [%{"b" => 1}, nil]}
          ])
        )

      assert candidates == %{"signup.mixed" => ["ok"]}
    end

    # sabotage: `declared_values/1` raising rather than answering `%{}` on a
    # shape `index/1` declines -> these go red. Same total-normalizer
    # discipline `declared_paths/1` is written under.
    test "an input that is not a document declares no enumerations" do
      assert Document.declared_values(nil) == %{}
      assert Document.declared_values(["signup.step", "card.brand"]) == %{}
      assert Document.declared_values(MapSet.new(["signup.step"])) == %{}
      assert Document.declared_values(%{"scopes" => "not a list"}) == %{}
    end
  end
end
