defmodule StatifierDatamodel.ConformanceTest do
  @moduledoc """
  ADR-0004 decision 7 - whether a value conforms to a type expression.

  The record's worked example, the library loan, is transcribed below, so the
  assertions are against the declarations and payloads the record publishes.
  The property tests draw from the nine scalars, from records and shapes
  built out of them, and from lists of each, and check `conforms/3` against
  the two answers beside it: `Coverage.missing/3`, whose fill rule
  `:missing` is, and `Types.satisfies/3`, which neither changes.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest StatifierDatamodel.Conformance

  alias StatifierDatamodel.{Conformance, Coverage, Declarations, Types}

  # ADR-0004's "Worked example" types, transcribed.
  @worked_types [
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
  ]

  @scalars ~w(string integer decimal boolean datetime duration date object list)

  defp worked, do: Declarations.from_document(%{"types" => @worked_types})

  defp renewal, do: {:declared, "loans.renewal"}

  describe "the worked example" do
    # Sabotage: checking a nil required field against its type instead of
    # reporting it :missing turned this test red at ["renewals"]; reverted.
    test "answers the three payloads ADR-0004 decision 7 shows" do
      declarations = worked()

      assert Conformance.conforms(declarations, renewal(), %{
               "copy_id" => "c-0412",
               "due_on" => "2026-11-02",
               "renewals" => 1
             }) == :ok

      assert Conformance.conforms(declarations, renewal(), %{
               "copy_id" => "c-0412",
               "due_on" => ~D[2026-11-02],
               "renewals" => 1
             }) == :ok

      assert Conformance.conforms(declarations, renewal(), %{
               "copy_id" => "c-0412",
               "due_on" => "next week",
               "renewals" => nil,
               "holds" => [%{"patron_id" => "p-77"}, %{}],
               "shelf" => "B3"
             }) ==
               {:error,
                [
                  {["due_on"], {:expected, :date}},
                  {["renewals"], :missing},
                  {["holds", 1, "patron_id"], :missing}
                ]}
    end

    # Sabotage: reading a declaration's fields as none (so a declared
    # record or shape accepted any value) turned this test red at the
    # due-soon notice; reverted.
    test "answers the record's other three sentences" do
      declarations = worked()

      returned = %{
        "copy_id" => "c-0412",
        "returned_at" => "2026-11-02T10:15:00Z",
        "condition" => "lost"
      }

      assert Conformance.conforms(declarations, {:declared, "loans.return"}, returned) == :ok

      assert Conformance.conforms(declarations, {:declared, "notices.due_soon"}, %{
               "patron_id" => "p-77"
             }) == {:error, [{["due_on"], :missing}]}

      assert Conformance.conforms(declarations, :unknown, %{"anything" => [1, "two"]}) == :ok
    end

    # Sabotage: reading a list item's index as 0 for every item turned this
    # test red at the third hold; reverted.
    test "a payload decoded from JSON conforms as it is spelled" do
      payload =
        JSON.decode!(
          ~s({"copy_id": "c-0412", "due_on": "2026-11-02", "renewals": 2,
                         "holds": [{"patron_id": "p-77"}, {"patron_id": "p-78"}, {"patron_id": 79}]})
        )

      assert Conformance.conforms(worked(), renewal(), payload) ==
               {:error, [{["holds", 2, "patron_id"], {:expected, :string}}]}
    end
  end

  describe "the nine scalars" do
    # Sabotage: accepting any number for :integer turned this test red at
    # 1.5; reverted.
    test "each accepts what a decoded JSON value spells, or the matching struct" do
      accepted = [
        {:string, "c-0412"},
        {:integer, 3},
        {:decimal, 3},
        {:decimal, 2.5},
        {:boolean, false},
        {:date, "2026-11-02"},
        {:date, ~D[2026-11-02]},
        {:datetime, "2026-11-02T10:15:00Z"},
        {:datetime, "2026-11-02T10:15:00-06:00"},
        {:datetime, ~U[2026-11-02 10:15:00Z]},
        {:duration, "P14D"},
        {:duration, "PT1H30M"},
        {:duration, Duration.new!(day: 14)},
        {:object, %{}},
        {:object, %{"shelf" => "B3"}},
        {:list, []},
        {:list, [1, "two"]}
      ]

      for {type, value} <- accepted do
        assert Conformance.conforms(%{}, type, value) == :ok, inspect({type, value})
      end

      refused = [
        {:string, 7},
        {:string, nil},
        {:integer, 1.5},
        {:integer, "3"},
        {:decimal, true},
        {:boolean, "true"},
        {:date, "next week"},
        {:date, "2026-11-02T10:15:00Z"},
        {:date, ~U[2026-11-02 10:15:00Z]},
        {:datetime, "2026-11-02"},
        {:datetime, 1_700_000_000},
        {:duration, "two weeks"},
        {:duration, 14},
        {:object, []},
        {:list, %{}}
      ]

      for {type, value} <- refused do
        assert Conformance.conforms(%{}, type, value) == {:error, [{[], {:expected, type}}]},
               inspect({type, value})
      end
    end

    # Sabotage: dropping the Decimal struct clause turned this test red at
    # the struct; dropping the string arm turned it red at "12.50";
    # reverted each.
    test "a decimal is a Decimal struct by its module name, or decision 4's string" do
      decimal = Map.put(%{sign: 1, coef: 1250, exp: -2}, :__struct__, Decimal)

      assert Conformance.conforms(%{}, :decimal, decimal) == :ok
      assert Conformance.conforms(%{}, :decimal, "12.50") == :ok
      assert Conformance.conforms(%{}, :decimal, "") == :ok
    end

    # Sabotage: dropping the expression-language arm from the duration check
    # turned this test red at "30s"; reverted.
    test "a duration is also decision 4's expression-language duration string" do
      for spelling <- ~w(30s 1h30m 3d8h30m 1mo 250ms 1.5s 0.5mo 1y2w 0s 30m3d) do
        assert Conformance.conforms(%{}, :duration, spelling) == :ok, spelling
      end
    end

    # Sabotage: treating every fraction as a whole number of milliseconds
    # turned this test red at "0.5ms"; reverted.
    test "an expression-language duration string is read whole" do
      for spelling <- [
            "",
            "30",
            "s",
            "1d ",
            " 1d",
            "-1d",
            ".5s",
            "1.s",
            "1x",
            "1d2",
            "0.5ms",
            "1.0001s"
          ] do
        assert Conformance.conforms(%{}, :duration, spelling) ==
                 {:error, [{[], {:expected, :duration}}]},
               inspect(spelling)
      end
    end

    # Sabotage: accepting a NaiveDateTime as a datetime turned this test red;
    # reverted.
    test "a NaiveDateTime, and a date-time string without an offset, are not a datetime" do
      assert Conformance.conforms(%{}, :datetime, ~N[2026-11-02 10:15:00]) ==
               {:error, [{[], {:expected, :datetime}}]}

      assert Conformance.conforms(%{}, :datetime, "2026-11-02T10:15:00") ==
               {:error, [{[], {:expected, :datetime}}]}
    end
  end

  describe "records, shapes and inline shapes" do
    # Sabotage: answering [] for a value that is not a map, against a
    # declaration, turned this test red; reverted.
    test "a value that is not a map is the type's mismatch at its path" do
      assert Conformance.conforms(worked(), renewal(), "c-0412") ==
               {:error, [{[], {:expected, renewal()}}]}

      assert Conformance.conforms(worked(), renewal(), %{
               "copy_id" => "c-0412",
               "due_on" => "2026-11-02",
               "renewals" => 1,
               "holds" => [nil]
             }) == {:error, [{["holds", 0], {:expected, {:declared, "loans.hold"}}}]}
    end

    # Sabotage: reading the fields of an inline shape as none (so it
    # accepted any value) turned this test red; reverted.
    test "an inline shape is checked member-wise, as a declaration is" do
      shape =
        {:shape,
         [
           %{name: "copy_id", type: :string, required?: true},
           %{name: "hold", type: {:declared, "loans.hold"}, required?: false},
           %{name: "copy_id", type: :integer, required?: true},
           %{type: :string, required?: true}
         ]}

      assert Conformance.conforms(worked(), shape, %{"copy_id" => "c-0412"}) == :ok

      assert Conformance.conforms(worked(), shape, %{"hold" => %{"patron_id" => 77}}) ==
               {:error, [{["copy_id"], :missing}, {["hold", "patron_id"], {:expected, :string}}]}
    end

    # Sabotage: reporting every key the type does not name turned this test
    # red at "shelf"; reverted.
    test "extra keys are ignored and one_of is not enforced" do
      returned = %{
        "copy_id" => "c-0412",
        "returned_at" => ~U[2026-11-02 10:15:00Z],
        "condition" => "on the moon",
        "shelf" => "B3",
        copy_id: 7
      }

      assert Conformance.conforms(worked(), {:declared, "loans.return"}, returned) == :ok
    end

    # Sabotage: answering :missing for an optional nil field turned this
    # test red; reverted.
    test "an optional field that is absent or nil conforms, and an atom key fills nothing" do
      assert Conformance.conforms(worked(), {:declared, "loans.return"}, %{
               "copy_id" => "c-0412",
               "returned_at" => "2026-11-02T10:15:00Z",
               "condition" => nil
             }) == :ok

      assert Conformance.conforms(worked(), {:declared, "notices.due_soon"}, %{
               patron_id: "p-77",
               due_on: "2026-11-02"
             }) == {:error, [{["patron_id"], :missing}, {["due_on"], :missing}]}
    end

    # Sabotage: refusing a value whose type is nil turned this test red at
    # "shelf_mark"; reverted.
    test "a field type or item type that named nothing is unknown and accepts anything" do
      declarations =
        Declarations.from_document(%{
          "types" => [
            %{
              "name" => "loans.copy",
              "kind" => "record",
              "label" => "Copy",
              "fields" => [
                %{"name" => "shelf_mark", "type" => "loans.shelf_mark", "required?" => true},
                %{"name" => "notes", "type" => "list", "item_type" => "loans.note"}
              ]
            }
          ]
        })

      {:ok, %{fields: [shelf_mark, notes]}} = Declarations.fetch(declarations, "loans.copy")
      assert {shelf_mark.type, notes.item_type} == {nil, nil}

      assert Conformance.conforms(declarations, {:declared, "loans.copy"}, %{
               "shelf_mark" => 42,
               "notes" => [1, "two", %{}]
             }) == :ok

      assert Conformance.conforms(declarations, {:declared, "loans.copy"}, %{}) ==
               {:error, [{["shelf_mark"], :missing}]}
    end

    # Sabotage: answering a mismatch for a declared name the declarations do
    # not hold turned this test red; reading declarations that are not a map
    # as holding the renewal turned it red at :not_declarations; reverted
    # each.
    test "an opaque string and an undeclared name accept anything, and nothing raises" do
      assert Conformance.conforms(worked(), {:opaque, "Settleable"}, 7) == :ok
      assert Conformance.conforms(worked(), {:declared, "loans.loss"}, 7) == :ok
      assert Conformance.conforms(worked(), nil, 7) == :ok
      assert Conformance.conforms(worked(), {:shape, :not_a_list}, 7) == :ok
      assert Conformance.conforms(:not_declarations, renewal(), 7) == :ok

      assert Conformance.conforms(
               %{"loans.odd" => :not_a_declaration},
               {:declared, "loans.odd"},
               7
             ) == :ok
    end

    # Sabotage: answering nothing for an improper list value turned this test
    # red at ["xs"]; reading an improper member list as one required member
    # turned it red at the shape; reverted each.
    test "an improper list is not a list, and an improper member list checks nothing" do
      xs = {:shape, [%{name: "xs", type: :list, item_type: :integer, required?: true}]}

      assert Conformance.conforms(%{}, xs, %{"xs" => [1 | 2]}) ==
               {:error, [{["xs"], {:expected, :list}}]}

      assert Conformance.conforms(%{}, :list, [1 | 2]) == {:error, [{[], {:expected, :list}}]}
      assert Conformance.conforms(%{}, {:shape, [1 | 2]}, %{}) == :ok

      assert Conformance.conforms(
               %{"loans.odd" => %{fields: [1 | 2]}},
               {:declared, "loans.odd"},
               %{}
             ) == :ok
    end
  end

  describe "the two answers beside it, unchanged" do
    # Pins what Types.satisfies/3 and Coverage.missing/3 answer over the
    # worked declarations, which this module reads and does not change.
    # Sabotage: making Coverage.missing/3 count a key whose value is not a
    # string as unfilled turned this test red; answering :covers for two
    # identical types in Types.satisfies/3 turned it red; reverted each.
    test "Types.satisfies/3 and Coverage.missing/3 answer as before" do
      declarations = worked()

      assert Types.satisfies(declarations, renewal(), {:declared, "notices.due_soon"}) ==
               {:missing, ["patron_id"]}

      assert Types.satisfies(declarations, :date, :date) == :identical
      assert Types.satisfies(declarations, :string, :date) == :not_assignable
      assert Types.satisfies(declarations, renewal(), :unknown) == :unknown

      assert Coverage.missing(declarations, "notices.due_soon", %{"patron_id" => 77}) ==
               {:ok, ["due_on"]}

      assert Coverage.missing(declarations, "notices.due_soon", %{"due_on" => "next week"}) ==
               {:ok, ["patron_id"]}

      assert Coverage.missing(declarations, "loans.renewal", %{}) == :error
    end
  end

  # -- properties --------------------------------------------------------------

  describe "properties" do
    # Sabotage: refusing a Duration struct turned this property red;
    # reverted.
    property "every scalar accepts each value generated to conform to it" do
      check all({spelling, value} <- conforming_scalar()) do
        assert Conformance.conforms(%{}, Types.scalar(spelling), value) == :ok
      end
    end

    # Sabotage: accepting a string for :integer turned this property red;
    # reverted.
    property "every scalar refuses a value of another kind, at the value's own path" do
      check all({spelling, value} <- refused_scalar()) do
        type = Types.scalar(spelling)
        assert Conformance.conforms(%{}, type, value) == {:error, [{[], {:expected, type}}]}
      end
    end

    # Sabotage: reversing a record's field order in the check turned this
    # property red; reverted.
    property "a record or shape accepts a conforming map, and names each field it breaks in order" do
      check all(
              {declarations, name, fields} <- declaration(),
              value <- conforming_map(fields),
              broken <- broken_fields(fields)
            ) do
        type = {:declared, name}
        assert Conformance.conforms(declarations, type, value) == :ok

        mutated =
          Enum.reduce(broken, value, fn {field_name, bad}, acc ->
            Map.put(acc, field_name, bad)
          end)

        expected =
          Enum.flat_map(fields, fn field ->
            case List.keyfind(broken, field["name"], 0) do
              nil -> []
              {name, nil} -> [{[name], :missing}]
              {name, _bad} -> [{[name], {:expected, Types.scalar(field["type"])}}]
            end
          end)

        answer = Conformance.conforms(declarations, type, mutated)
        if expected == [], do: assert(answer == :ok), else: assert(answer == {:error, expected})
      end
    end

    # Sabotage: answering nothing for an item of a list field turned this
    # property red; reverted.
    property "a list descends its item type, items in index order" do
      check all(
              spelling <- member_of(@scalars),
              items <- list_of(conforming(spelling), max_length: 5),
              bad_at <- list_of(integer(0..5), max_length: 3)
            ) do
        declarations =
          Declarations.from_document(%{
            "types" => [
              %{
                "name" => "loans.shelf",
                "kind" => "record",
                "label" => "Shelf",
                "fields" => [%{"name" => "items", "type" => "list", "item_type" => spelling}]
              }
            ]
          })

        bad_at = bad_at |> Enum.filter(&(&1 < length(items))) |> Enum.uniq() |> Enum.sort()
        mutated = Enum.reduce(bad_at, items, &List.replace_at(&2, &1, refused_value(spelling)))

        answer =
          Conformance.conforms(declarations, {:declared, "loans.shelf"}, %{"items" => mutated})

        case bad_at do
          [] ->
            assert answer == :ok

          indexes ->
            type = Types.scalar(spelling)
            assert answer == {:error, for(i <- indexes, do: {["items", i], {:expected, type}})}
        end
      end
    end

    # Sabotage: treating a field present with any value as filled for
    # :missing (ignoring nil) turned this property red; reverted.
    property "the :missing fields of a shape are exactly what Coverage.missing/3 names" do
      check all(
              {declarations, name, _fields} <- declaration("shape"),
              value <-
                map_of(string(:alphanumeric, max_length: 3), one_of([constant(nil), integer()]),
                  max_length: 6
                )
            ) do
        {:ok, coverage} = Coverage.missing(declarations, name, value)

        missing =
          case Conformance.conforms(declarations, {:declared, name}, value) do
            :ok -> []
            {:error, mismatches} -> for {[field], :missing} <- mismatches, do: field
          end

        assert missing == coverage
      end
    end

    # Sabotage: answering {:error, []} for a value that conforms turned this
    # property red; reverted.
    property "it is total: any type, any value, :ok or a non-empty list of mismatches" do
      check all(
              type <-
                one_of([
                  member_of([:unknown, nil | Enum.map(@scalars, &Types.scalar/1)]),
                  constant({:declared, "loans.renewal"}),
                  constant({:declared, "loans.loss"}),
                  constant({:opaque, "Settleable"}),
                  term()
                ]),
              value <- one_of([term(), string(:printable), binary()])
            ) do
        answer = Conformance.conforms(worked(), type, value)

        assert answer == :ok or
                 match?({:error, [{path, _reason} | _]} when is_list(path), answer)
      end
    end
  end

  # -- generators --------------------------------------------------------------

  defp conforming_scalar do
    bind(member_of(@scalars), fn spelling -> tuple({constant(spelling), conforming(spelling)}) end)
  end

  defp refused_scalar do
    bind(member_of(@scalars), fn spelling -> tuple({constant(spelling), refused(spelling)}) end)
  end

  defp conforming("string"), do: string(:printable)
  defp conforming("integer"), do: integer()

  defp conforming("decimal") do
    one_of([
      integer(),
      float(),
      string(:alphanumeric),
      map(
        tuple({integer(), integer(-10..10)}),
        fn {coef, exp} ->
          Map.put(%{sign: 1, coef: abs(coef), exp: exp}, :__struct__, Decimal)
        end
      )
    ])
  end

  defp conforming("boolean"), do: boolean()

  defp conforming("date") do
    map(tuple({integer(-50_000..50_000), boolean()}), fn {days, as_string?} ->
      date = Date.add(~D[2000-01-01], days)
      if as_string?, do: Date.to_iso8601(date), else: date
    end)
  end

  defp conforming("datetime") do
    map(
      tuple({integer(0..4_000_000_000), member_of([0, 3600, -21_600, 19_800]), boolean()}),
      fn {seconds, offset, as_string?} ->
        datetime = DateTime.from_unix!(seconds)

        cond do
          not as_string? ->
            datetime

          offset == 0 ->
            DateTime.to_iso8601(datetime)

          true ->
            datetime
            |> DateTime.add(offset)
            |> DateTime.to_naive()
            |> NaiveDateTime.to_iso8601()
            |> Kernel.<>(offset_suffix(offset))
        end
      end
    )
  end

  defp conforming("duration") do
    map(
      tuple(
        {integer(0..400), integer(0..59), integer(0..59), member_of([:struct, :iso, :expression])}
      ),
      fn {days, hours, minutes, spelling} ->
        duration = Duration.new!(day: days, hour: hours, minute: minutes)

        case spelling do
          :struct -> duration
          :iso -> Duration.to_iso8601(duration)
          :expression -> "#{days}d#{hours}h#{minutes}m"
        end
      end
    )
  end

  defp conforming("object"), do: map_of(string(:alphanumeric), integer(), max_length: 3)
  defp conforming("list"), do: list_of(one_of([integer(), string(:alphanumeric)]), max_length: 3)

  defp offset_suffix(offset) do
    sign = if offset < 0, do: "-", else: "+"
    abs_offset = abs(offset)
    hours = abs_offset |> div(3600) |> Integer.to_string() |> String.pad_leading(2, "0")

    minutes =
      abs_offset |> rem(3600) |> div(60) |> Integer.to_string() |> String.pad_leading(2, "0")

    sign <> hours <> ":" <> minutes
  end

  # A value of a kind the scalar does not accept, drawn from a kind no arm
  # of that scalar reads.
  defp refused("string"), do: one_of([integer(), boolean(), constant(nil)])
  defp refused("integer"), do: one_of([float(), string(:alphanumeric), boolean()])

  defp refused("decimal"),
    do: one_of([boolean(), constant(nil), list_of(integer(), max_length: 2)])

  defp refused("boolean"), do: one_of([integer(), string(:alphanumeric), constant(nil)])

  defp refused("date"),
    do: one_of([integer(), boolean(), map(string(:alphanumeric), &("x" <> &1))])

  defp refused("datetime"),
    do: one_of([integer(), constant(~N[2026-11-02 10:15:00]), constant(~D[2026-11-02])])

  defp refused("duration"),
    do: one_of([integer(), boolean(), map(string(:alphanumeric), &("x" <> &1))])

  defp refused("object"),
    do: one_of([integer(), list_of(integer(), max_length: 2), string(:alphanumeric)])

  defp refused("list"), do: one_of([integer(), constant(%{}), string(:alphanumeric)])

  # One fixed refused value per scalar, for the list property.
  defp refused_value("list"), do: %{}
  defp refused_value(_any_other_scalar), do: :not_a_json_value

  # A declaration of `kind` (or either kind), its fields drawn from the nine
  # scalars with distinct names, each required or optional.
  defp declaration(only_kind \\ nil) do
    gen all(
          kind <- if(only_kind, do: constant(only_kind), else: member_of(["record", "shape"])),
          names <-
            uniq_list_of(string(:alphanumeric, min_length: 1, max_length: 3), max_length: 6),
          specs <- list_of(tuple({member_of(@scalars), boolean()}), length: length(names))
        ) do
      fields =
        names
        |> Enum.zip(specs)
        |> Enum.map(fn {name, {type, required?}} ->
          %{"name" => name, "type" => type, "required?" => required?}
        end)

      declarations =
        Declarations.from_document(%{
          "types" => [
            %{
              "name" => "loans.generated",
              "kind" => kind,
              "label" => "Generated",
              "fields" => fields
            }
          ]
        })

      {declarations, "loans.generated", fields}
    end
  end

  # A map that conforms: every required field present and conforming, each
  # optional one absent, nil, or conforming.
  defp conforming_map(fields) do
    fields
    |> Enum.map(fn field ->
      value = conforming(field["type"])

      if field["required?"] do
        map(value, &{field["name"], {:present, &1}})
      else
        one_of([
          constant({field["name"], :absent}),
          constant({field["name"], {:present, nil}}),
          map(value, &{field["name"], {:present, &1}})
        ])
      end
    end)
    |> fixed_list()
    |> map(fn pairs -> for {name, {:present, v}} <- pairs, into: %{}, do: {name, v} end)
  end

  # Some of the fields, each broken: a required field set to nil, or any
  # field set to a value of a kind its scalar refuses.
  defp broken_fields(fields) do
    fields
    |> Enum.map(fn field ->
      broken =
        if field["required?"],
          do: one_of([constant(nil), refused(field["type"])]),
          else: filter(refused(field["type"]), &(&1 != nil))

      one_of([constant(nil), map(broken, &{field["name"], &1})])
    end)
    |> fixed_list()
    |> map(fn broken -> Enum.reject(broken, &is_nil/1) end)
  end
end
