defmodule StatifierDatamodel.Compatibility do
  @moduledoc """
  ADR-0001 decision 9: what a redefined declaration takes away from the one
  it replaces.

  `breaks/2` is given the declaration a name had and the declaration
  replacing it, and lists every way the new one **narrows** the old one -
  every reason a read that held under the old declaration might not hold
  under the new. The list is empty when the redefinition takes nothing away,
  and a name declared on neither side is an `:error` rather than an empty
  list: nothing was redefined, so there is nothing to answer.

  ## The six rows

  The record's table, kept literally, with the kind each row reports. Five
  ways a redefinition narrows:

  | Change | Verdict | Kind | Break |
  |---|---|---|---|
  | a field removed | breaking | `:field_removed` | `{:field_removed, name}` |
  | a field's `type` changed | breaking | `:type_changed` | `{:type_changed, name}` |
  | a field optional -> required | breaking | `:made_required` | `{:made_required, name}` |
  | a required field added | breaking | `:required_added` | `{:required_added, name}` |
  | a field required -> optional | breaking | `:made_optional` | `{:made_optional, name}` |

  and one way it does not:

  | Change | Verdict | Kind |
  |---|---|---|
  | an optional field added | compatible | none - nothing is reported |

  ## The kind is the first element

  A break's first element **is** the row it came from: one atom per breaking
  row of the table above, and the same atom every time that row is the reason.
  An embedder wording a warning matches on it and never re-derives from the
  two declarations why the row broke.

      case Compatibility.breaks(old, new) do
        :error -> "nothing was redefined"
        breaks -> Enum.map(breaks, fn
          {:field_removed, name} -> "\#{name} is gone"
          {:type_changed, name} -> "\#{name} holds a different type"
          {:made_required, name} -> "\#{name} must now be there"
          {:required_added, name} -> "\#{name} was added and must be there"
          {:made_optional, name} -> "\#{name} is no longer promised"
        end)
      end

  The vocabulary is closed at those five and is the `break()` type: a `case`
  that names all five is exhaustive over every break this module reports, and
  a sixth kind would be a new row in the record's table, not a new spelling of
  an old one. The compatible row reports nothing at all, so there is no kind
  for *an optional field added* to match on - an empty list is the answer.

  The asymmetry is the whole point: this answers *may a reader keep reading*,
  not *did anything change*. A declaration that gains an optional field takes
  nothing away from a read written against the old one.

  ## Why relaxing a field is a break

  A record field that goes required -> optional stops promising its value,
  and the read check stopped reading an optional record field as covering a
  required shape field when decision 8 was amended on 2026-09-06. A read that
  held under the old declaration therefore does not hold under the new, which
  is the one question this module answers. The row was compatible while step
  3 ignored the record side's `required?`; the amendment of 2026-09-06 to
  decision 9 moves it.

  ## A `one_of` is a completion hint, never a break

  A field's `one_of` lists the values a host expects and an editor draws as
  choices. It is not a constraint: a value control fed from it still admits
  anything the author types, and nothing in this package reads it as a
  promise. Adding one, removing one, reordering one, widening one and
  shrinking one are therefore all compatible, and the key means on a
  declaration field exactly what it means on an entry (decision 9 as amended
  2026-09-06).

  ## What is not a break

  A field's `item_type` is not compared, for the same reason the read check
  does not descend into it: `list` satisfies `list`, and narrowing that is a
  decision no record has taken. A changed `label`, a changed `note`, a
  changed `one_of` and a changed `kind` are not among the record's five
  either - `label` and `note` carry no contract, `one_of` is a hint, and a
  name that changes kind is a redefinition this vocabulary has no word for.
  Nothing here raises: an input that is not a declaration is read as *not
  declared on that side*.

  ## Deterministic order

  Breaks are ordered by field name, then by reason in the order the record's
  table lists them, so two runs over the same pair produce the same list and
  a caller may compare two lists directly. One field can carry several
  breaks: a field that changed type and was relaxed at once names both.
  """

  alias StatifierDatamodel.Declarations

  @typedoc """
  One way a redefinition narrows what it replaces: the kind, which names the
  row of the record's table it came from, and the field it happened to.

  The kinds, in the table's order: `:field_removed` for a field removed,
  `:type_changed` for a field's `type` changed, `:made_required` for a field
  optional -> required, `:required_added` for a required field added, and
  `:made_optional` for a field required -> optional. The vocabulary is closed
  at those five.
  """
  @type break ::
          {:field_removed, String.t()}
          | {:type_changed, String.t()}
          | {:made_required, String.t()}
          | {:required_added, String.t()}
          | {:made_optional, String.t()}

  # The record's own table order, which is the tie-break between two breaks
  # on one field name.
  @reasons [:field_removed, :type_changed, :made_required, :required_added, :made_optional]

  @doc """
  Every way `new` narrows `old`, ordered by field name then by reason.

  Each break names its kind first - `:field_removed`, `:type_changed`,
  `:made_required`, `:required_added` or `:made_optional`, one per breaking
  row of the record's table - and the field second, so a caller words a
  warning by matching the kind rather than by comparing the two declarations
  again.

  `nil` on a side means the name is not declared there: a declaration that
  went away removes all of its fields, and one that appeared adds all of its
  required ones. A name declared on neither side is `:error`.

      iex> alias StatifierDatamodel.{Compatibility, Declarations}
      iex> was = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "label" => "Card", "fields" => [
      ...>     %{"name" => "brand", "type" => "string", "required?" => true},
      ...>     %{"name" => "last4", "type" => "string", "required?" => true}]}]})
      iex> now = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "label" => "Card", "fields" => [
      ...>     %{"name" => "brand", "type" => "string", "required?" => true},
      ...>     %{"name" => "expires_on", "type" => "date", "required?" => true}]}]})
      iex> {:ok, old} = Declarations.fetch(was, "cards.card")
      iex> {:ok, new} = Declarations.fetch(now, "cards.card")
      iex> Compatibility.breaks(old, new)
      [{:required_added, "expires_on"}, {:field_removed, "last4"}]

  A redefinition that only adds an optional field takes nothing away, and
  neither does one that only edits a completion hint:

      iex> alias StatifierDatamodel.{Compatibility, Declarations}
      iex> was = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "fields" => [
      ...>     %{"name" => "brand", "type" => "string", "required?" => true,
      ...>       "one_of" => ["visa", "mastercard", "amex"]}]}]})
      iex> now = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "fields" => [
      ...>     %{"name" => "brand", "type" => "string", "required?" => true,
      ...>       "one_of" => ["visa"]},
      ...>     %{"name" => "last4", "type" => "string"}]}]})
      iex> {:ok, old} = Declarations.fetch(was, "cards.card")
      iex> {:ok, new} = Declarations.fetch(now, "cards.card")
      iex> Compatibility.breaks(old, new)
      []

  Relaxing a required field does take something away: the record stops
  promising the value, so a shape that requires it stops being covered.

      iex> alias StatifierDatamodel.{Compatibility, Declarations}
      iex> was = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "fields" => [
      ...>     %{"name" => "brand", "type" => "string", "required?" => true}]}]})
      iex> now = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "fields" => [
      ...>     %{"name" => "brand", "type" => "string", "required?" => false}]}]})
      iex> {:ok, old} = Declarations.fetch(was, "cards.card")
      iex> {:ok, new} = Declarations.fetch(now, "cards.card")
      iex> Compatibility.breaks(old, new)
      [{:made_optional, "brand"}]

      iex> StatifierDatamodel.Compatibility.breaks(nil, nil)
      :error
  """
  @spec breaks(Declarations.declaration() | nil, Declarations.declaration() | nil) ::
          [break()] | :error
  def breaks(old, new) do
    case {declaration(old), declaration(new)} do
      {nil, nil} ->
        :error

      {old, new} ->
        old
        |> narrowings(new)
        |> Enum.sort_by(fn {reason, name} ->
          {name, Enum.find_index(@reasons, &(&1 == reason))}
        end)
    end
  end

  # -- the five narrowings ---------------------------------------------------

  @spec narrowings(Declarations.declaration() | nil, Declarations.declaration() | nil) :: [
          break()
        ]
  defp narrowings(old, new) do
    old_fields = fields(old)
    new_fields = fields(new)
    was = Map.new(old_fields, &{&1.name, &1})
    now = Map.new(new_fields, &{&1.name, &1})

    kept =
      Enum.flat_map(old_fields, fn field ->
        case Map.fetch(now, field.name) do
          :error -> [{:field_removed, field.name}]
          {:ok, replacement} -> changes(field, replacement)
        end
      end)

    added =
      for field <- new_fields,
          not Map.has_key?(was, field.name),
          field.required?,
          do: {:required_added, field.name}

    kept ++ added
  end

  # A field both declarations carry: the three ways it can narrow. Its
  # `one_of` is not among them - a hint narrows nothing.
  @spec changes(Declarations.field(), Declarations.field()) :: [break()]
  defp changes(was, now) do
    type_changed = if was.type != now.type, do: [{:type_changed, was.name}], else: []

    made_required =
      if not was.required? and now.required?, do: [{:made_required, was.name}], else: []

    made_optional =
      if was.required? and not now.required?, do: [{:made_optional, was.name}], else: []

    type_changed ++ made_required ++ made_optional
  end

  @spec fields(Declarations.declaration() | nil) :: [Declarations.field()]
  defp fields(%{fields: fields}), do: fields
  defp fields(nil), do: []

  # Not declared on this side, and an input that is not a declaration is read
  # as exactly that rather than raised on.
  @spec declaration(term()) :: Declarations.declaration() | nil
  defp declaration(%{name: name, kind: kind, fields: fields} = declaration)
       when is_binary(name) and kind in [:record, :shape] and is_list(fields),
       do: declaration

  defp declaration(_absent_or_not_a_declaration), do: nil
end
