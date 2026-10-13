defmodule StatifierDatamodel.Conformance do
  @moduledoc """
  ADR-0004 decision 7: whether a value conforms to a type expression.

  `conforms/3` is given the declarations, a type expression and a value -
  a payload a host decoded from JSON or built in Elixir - and answers `:ok`,
  or `{:error, mismatches}` naming every place the value does not conform.
  It checks against a declared record, a declared shape or an inline shape
  alike: a payload is checked against what its event declares it carries.

  `StatifierDatamodel.Types.satisfies/3` decides a type against a type, and
  `StatifierDatamodel.Coverage.missing/3` decides which required fields of a
  shape a map leaves unfilled. This module is the third question beside
  them, a value against a type, and neither of the other two changes any
  answer it gives.

  ## A mismatch: a path and a reason

  Each mismatch is `{path, reason}`. `path` is a list of segments, a string
  for a field name and an integer for a list index; the value itself is at
  `[]`. `reason` is one of two:

    * `:missing` - a required field is absent or `nil`, which is
      `StatifierDatamodel.Coverage.missing/3`'s fill rule;
    * `{:expected, type}` - the value at `path` does not conform to `type`,
      the type expression it failed.

  Mismatches come in the type's field order, depth first, and a list's
  items in index order.

  ## What each type accepts

  | Type | A value conforms when it is |
  |---|---|
  | `:string` | a binary |
  | `:integer` | an integer |
  | `:decimal` | an integer, a float, a `Decimal` struct, or a string |
  | `:boolean` | a boolean |
  | `:date` | an ISO 8601 date string, or a `Date` |
  | `:datetime` | an ISO 8601 date-time string carrying an offset, or a `DateTime` |
  | `:duration` | an ISO 8601 duration string, an expression-language duration string, or a `Duration` |
  | `:object` | a map |
  | `:list` | a list, whose items conform to the field's `item_type` when it is known |
  | a declared record or shape, or an inline shape | a map whose fields conform, below |
  | `:unknown`, `{:opaque, _}`, a declared name the declarations do not hold, or `nil` | anything |

  A `Decimal` struct is recognised by its module name; the package takes no
  dependency on it. The string spellings of `:decimal` and `:duration` are
  ADR-0001 decision 4's, accepted beside the ones a decoded JSON value
  spells. Decision 4 says a `decimal` "is a string" and states no grammar
  for it, so any string conforms. An expression-language duration string
  is one or more `<digits>(.<digits>)?<unit>` pairs, the unit one of `y`,
  `mo`, `w`, `d`, `h`, `m`, `s` and `ms`, with no whitespace and no sign,
  and a fraction that comes to a whole number of milliseconds (`30s`,
  `1h30m`, `1.5s`): the rule the expression language's own duration parse
  applies to a whole string, followed here without depending on it.

  A `NaiveDateTime` carries no offset and does not conform to `:datetime`,
  and neither does a date-time string without one. A field whose type, or a
  `list` field whose `item_type`, named nothing the document declares is
  read as unknown, as an undeclared name is everywhere in this package.

  ## A record, a shape or an inline shape

  The value must be a map, read with the strings the declaration spells, as
  `StatifierDatamodel.Coverage.missing/3` reads one: a key spelled as an atom
  is not the field's key. Then each field, in the type's order:

    * absent or `nil` - a `:missing` mismatch when the field is required,
      and nothing when it is optional;
    * present - checked against the field's type, and a `list` field's
      items against its `item_type`, with the field's name, and an item's
      index, added to the path.

  A key the type does not name is ignored, because every object is open, and
  a field's `one_of` is a hint and is not checked. A record and a shape are
  checked the same way: the difference between them is what the read check
  decides, not what a value carries.

  Every answer is a fact. Nothing raises, nothing is enforced at run time,
  and whether a mismatch stops a host's pipeline is the host's to decide
  (ADR-0001 decision 12).
  """

  alias StatifierDatamodel.{Declarations, Types}

  @typedoc "Where a mismatch is: a field name or a list index per segment, `[]` the value itself."
  @type path :: [String.t() | non_neg_integer()]

  @typedoc "Why the value at a path does not conform."
  @type reason :: :missing | {:expected, Types.t()}

  @typedoc "One place a value does not conform to its type."
  @type mismatch :: {path(), reason()}

  # A field of a record, a shape or an inline shape, as this module reads it.
  @typep field :: %{
           name: String.t(),
           type: term(),
           item_type: term(),
           required?: boolean()
         }

  # The expression language's duration string, whole: one or more
  # `<digits>(.<digits>)?<unit>` pairs, `mo` and `ms` tried before the
  # one-letter units so `1mo` is a month and not a minute.
  @expression_duration ~r/\A(?:[0-9]+(?:\.[0-9]+)?(?:mo|ms|y|w|d|h|m|s))+\z/
  @expression_duration_pair ~r/[0-9]+(?:\.([0-9]+))?(mo|ms|y|w|d|h|m|s)/

  # Each unit in whole milliseconds, a month 30 days and a year 365, which is
  # what decides whether a fraction comes to a whole number of them.
  @unit_milliseconds %{
    "ms" => 1,
    "s" => 1_000,
    "m" => 60_000,
    "h" => 3_600_000,
    "d" => 86_400_000,
    "w" => 604_800_000,
    "mo" => 2_592_000_000,
    "y" => 31_536_000_000
  }

  @doc """
  Whether `value` conforms to `type`: `:ok`, or every mismatch in order.

  The library loan. A renewal is a record whose holds are a list of another
  record:

      iex> alias StatifierDatamodel.{Conformance, Declarations}
      iex> declarations = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "loans.renewal", "kind" => "record", "label" => "Renewal", "fields" => [
      ...>     %{"name" => "copy_id", "type" => "string", "required?" => true},
      ...>     %{"name" => "due_on", "type" => "date", "required?" => true},
      ...>     %{"name" => "renewals", "type" => "integer", "required?" => true},
      ...>     %{"name" => "holds", "type" => "list", "item_type" => "loans.hold"}]},
      ...>   %{"name" => "loans.hold", "kind" => "record", "label" => "Hold", "fields" => [
      ...>     %{"name" => "patron_id", "type" => "string", "required?" => true}]}]})
      iex> Conformance.conforms(declarations, {:declared, "loans.renewal"},
      ...>   %{"copy_id" => "c-0412", "due_on" => "2026-11-02", "renewals" => 1})
      :ok
      iex> Conformance.conforms(declarations, {:declared, "loans.renewal"},
      ...>   %{"copy_id" => "c-0412", "due_on" => ~D[2026-11-02], "renewals" => 1})
      :ok
      iex> Conformance.conforms(declarations, {:declared, "loans.renewal"},
      ...>   %{"copy_id" => "c-0412", "due_on" => "next week", "renewals" => nil,
      ...>     "holds" => [%{"patron_id" => "p-77"}, %{}], "shelf" => "B3"})
      {:error, [{["due_on"], {:expected, :date}},
                {["renewals"], :missing},
                {["holds", 1, "patron_id"], :missing}]}

  An inline shape is checked the same way, and a scalar on its own is the
  value at `[]`:

      iex> alias StatifierDatamodel.Conformance
      iex> Conformance.conforms(%{}, {:shape, [%{name: "patron_id", type: :string, required?: true}]},
      ...>   %{"patron_id" => 77})
      {:error, [{["patron_id"], {:expected, :string}}]}
      iex> Conformance.conforms(%{}, :duration, "1h30m")
      :ok
      iex> Conformance.conforms(%{}, :datetime, ~N[2026-11-02 10:00:00])
      {:error, [{[], {:expected, :datetime}}]}
      iex> Conformance.conforms(%{}, :unknown, {:anything, "at all"})
      :ok
  """
  @spec conforms(Declarations.t(), Types.t(), term()) :: :ok | {:error, [mismatch(), ...]}
  def conforms(declarations, type, value) do
    declarations = if is_map(declarations), do: declarations, else: %{}

    case check(declarations, type, nil, value, []) do
      [] -> :ok
      mismatches -> {:error, mismatches}
    end
  end

  # -- the check ---------------------------------------------------------------

  # The mismatches of `value` against `type`, in order; `item_type` is the
  # one a `list` field carries, and `at` is the path so far, reversed.
  @spec check(map(), term(), term(), term(), [String.t() | non_neg_integer()]) :: [mismatch()]
  defp check(declarations, type, item_type, value, at) do
    case fields(declarations, type) do
      {:ok, fields} -> check_fields(declarations, type, fields, value, at)
      :none -> check_scalar(declarations, type, item_type, value, at)
    end
  end

  # The fields a type is checked by, when it is a declaration or an inline
  # shape; `:none` for every other type.
  @spec fields(map(), term()) :: {:ok, [field()]} | :none
  defp fields(declarations, {:declared, name}) when is_binary(name) do
    case Map.fetch(declarations, name) do
      {:ok, %{fields: fields}} when is_list(fields) -> {:ok, normalize(fields)}
      _not_declared -> :none
    end
  end

  defp fields(_declarations, {:shape, members}) when is_list(members),
    do: {:ok, normalize(members)}

  defp fields(_declarations, _not_a_declaration_or_shape), do: :none

  @spec check_fields(map(), term(), [field()], term(), list()) :: [mismatch()]
  defp check_fields(declarations, _type, fields, value, at) when is_map(value) do
    Enum.flat_map(fields, fn field ->
      case Map.get(value, field.name) do
        nil when field.required? -> [{Enum.reverse([field.name | at]), :missing}]
        nil -> []
        present -> check(declarations, field.type, field.item_type, present, [field.name | at])
      end
    end)
  end

  defp check_fields(_declarations, type, _fields, _not_a_map, at),
    do: [{Enum.reverse(at), {:expected, type}}]

  @spec check_scalar(map(), term(), term(), term(), list()) :: [mismatch()]
  defp check_scalar(declarations, :list, item_type, value, at) when is_list(value) do
    if known?(item_type) do
      value
      |> Enum.with_index()
      |> Enum.flat_map(fn {item, index} ->
        check(declarations, item_type, nil, item, [index | at])
      end)
    else
      []
    end
  end

  defp check_scalar(_declarations, type, _item_type, value, at) do
    if accepts?(type, value), do: [], else: [{Enum.reverse(at), {:expected, type}}]
  end

  # Whether a list's items have a type to be checked against. A `nil` item
  # type named nothing the document declares, and is unknown.
  @spec known?(term()) :: boolean()
  defp known?(nil), do: false
  defp known?(:unknown), do: false
  defp known?(_type), do: true

  # The nine, and what accepts anything: `:unknown`, an opaque string, a
  # declared name the declarations do not hold, `nil`, and anything outside
  # the grammar, which is what keeps the check total.
  @spec accepts?(term(), term()) :: boolean()
  defp accepts?(:string, value), do: is_binary(value)
  defp accepts?(:integer, value), do: is_integer(value)
  defp accepts?(:decimal, value), do: decimal?(value)
  defp accepts?(:boolean, value), do: is_boolean(value)
  defp accepts?(:date, value), do: date?(value)
  defp accepts?(:datetime, value), do: datetime?(value)
  defp accepts?(:duration, value), do: duration?(value)
  defp accepts?(:object, value), do: is_map(value)
  defp accepts?(:list, value), do: is_list(value)
  defp accepts?(_unknown_or_outside_the_grammar, _value), do: true

  @spec decimal?(term()) :: boolean()
  defp decimal?(%{__struct__: Decimal}), do: true
  defp decimal?(value), do: is_integer(value) or is_float(value) or is_binary(value)

  @spec date?(term()) :: boolean()
  defp date?(%Date{}), do: true
  defp date?(value) when is_binary(value), do: match?({:ok, _date}, Date.from_iso8601(value))
  defp date?(_other), do: false

  # An offset is what a date-time carries and a naive one does not, so a
  # `NaiveDateTime`, and a string without an offset, are not one.
  @spec datetime?(term()) :: boolean()
  defp datetime?(%DateTime{}), do: true

  defp datetime?(value) when is_binary(value),
    do: match?({:ok, _datetime, _offset}, DateTime.from_iso8601(value))

  defp datetime?(_other), do: false

  @spec duration?(term()) :: boolean()
  defp duration?(%Duration{}), do: true

  defp duration?(value) when is_binary(value) do
    match?({:ok, _duration}, Duration.from_iso8601(value)) or expression_duration?(value)
  end

  defp duration?(_other), do: false

  @spec expression_duration?(String.t()) :: boolean()
  defp expression_duration?(value) do
    Regex.match?(@expression_duration, value) and
      @expression_duration_pair
      |> Regex.scan(value, capture: :all_but_first)
      |> Enum.all?(&whole_milliseconds?/1)
  end

  # A pair with no fraction is whole; a fraction is when it comes to a whole
  # number of milliseconds of its unit.
  @spec whole_milliseconds?([String.t()]) :: boolean()
  defp whole_milliseconds?(["", _unit]), do: true

  defp whole_milliseconds?([fraction, unit]) do
    rem(
      String.to_integer(fraction) * Map.fetch!(@unit_milliseconds, unit),
      Integer.pow(10, byte_size(fraction))
    ) == 0
  end

  # A declaration's fields or an inline shape's members, read the same way:
  # one with no usable name contributes nothing, and a repeated name keeps
  # its first occurrence, the rule `Declarations` uses for a repeated field.
  @spec normalize([term()]) :: [field()]
  defp normalize(fields) do
    fields
    |> Enum.flat_map(fn
      %{name: name} = raw when is_binary(name) and name != "" ->
        [
          %{
            name: name,
            type: Map.get(raw, :type),
            item_type: Map.get(raw, :item_type),
            required?: Map.get(raw, :required?) == true
          }
        ]

      _unnamed ->
        []
    end)
    |> Enum.uniq_by(& &1.name)
  end
end
