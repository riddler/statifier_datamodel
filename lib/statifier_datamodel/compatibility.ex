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

  ## The eight rows

  The record's table, kept literally. Five ways a redefinition narrows:

  | Change | Verdict | Break |
  |---|---|---|
  | a field removed | breaking | `{:field_removed, name}` |
  | a field's `type` changed | breaking | `{:type_changed, name}` |
  | a field optional -> required | breaking | `{:made_required, name}` |
  | a required field added | breaking | `{:required_added, name}` |
  | a field's `one_of` value group added | breaking | `{:group_added, name}` |

  and three ways it does not:

  | Change | Verdict |
  |---|---|
  | an optional field added | compatible |
  | a field required -> optional | compatible |
  | a field's `one_of` value group removed | compatible |

  The asymmetry is the whole point: this answers *may a reader keep reading*,
  not *did anything change*. Widening a declaration - more fields to have,
  fewer to supply, more values admitted - takes nothing away from a read
  written against the old one.

  ## A value group compares by value, with order ignored

  A field's `one_of` is compared as a set, so reordering one is no change.
  A group is **added** when the new declaration constrains where the old one
  did not, and also when the new group admits fewer values than the old: a
  value a document could carry before and cannot now is the same loss of a
  read either way, which is why the record calls shrinking a group breaking
  on the same reasoning as a type change. A group removed, or widened,
  admits everything it did before and is compatible.

  ## What is not a break

  A field's `item_type` is not compared, for the same reason the read check
  does not descend into it: `list` satisfies `list`, and narrowing that is a
  decision no record has taken. A changed `label`, a changed `note` and a
  changed `kind` are not among the record's five either - `label` and `note`
  carry no contract, and a name that changes kind is a redefinition this
  vocabulary has no word for. Nothing here raises: an input that is not a
  declaration is read as *not declared on that side*.

  ## Deterministic order

  Breaks are ordered by field name, then by reason in the order the record
  lists them, so two runs over the same pair produce the same list and a
  caller may compare two lists directly. One field can carry several breaks:
  a field that changed type and became required at once names both.
  """

  alias StatifierDatamodel.Declarations

  @typedoc """
  One way a redefinition narrows what it replaces, naming the field it
  happened to.
  """
  @type break ::
          {:field_removed, String.t()}
          | {:type_changed, String.t()}
          | {:required_added, String.t()}
          | {:made_required, String.t()}
          | {:group_added, String.t()}

  # The record's own order, which is the tie-break between two breaks on one
  # field name.
  @reasons [:field_removed, :type_changed, :required_added, :made_required, :group_added]

  @doc """
  Every way `new` narrows `old`, ordered by field name then by reason.

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

  A redefinition that only widens takes nothing away:

      iex> alias StatifierDatamodel.{Compatibility, Declarations}
      iex> was = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "fields" => [
      ...>     %{"name" => "brand", "type" => "string", "required?" => true}]}]})
      iex> now = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "fields" => [
      ...>     %{"name" => "brand", "type" => "string"},
      ...>     %{"name" => "last4", "type" => "string"}]}]})
      iex> {:ok, old} = Declarations.fetch(was, "cards.card")
      iex> {:ok, new} = Declarations.fetch(now, "cards.card")
      iex> Compatibility.breaks(old, new)
      []

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

  # A field both declarations carry: the three ways it can narrow.
  @spec changes(Declarations.field(), Declarations.field()) :: [break()]
  defp changes(was, now) do
    type_changed = if was.type != now.type, do: [{:type_changed, was.name}], else: []

    made_required =
      if not was.required? and now.required?, do: [{:made_required, was.name}], else: []

    group_added =
      if group_added?(was.one_of, now.one_of), do: [{:group_added, was.name}], else: []

    type_changed ++ made_required ++ group_added
  end

  # A group is added when the new declaration admits a value the old one did
  # not have to reject: no group at all admits everything, so gaining one
  # narrows, and so does shrinking one. Order is ignored on both sides.
  @spec group_added?(term(), term()) :: boolean()
  defp group_added?(_was, nil), do: false
  defp group_added?(nil, now) when is_list(now), do: true

  defp group_added?(was, now) when is_list(was) and is_list(now) do
    not MapSet.subset?(MapSet.new(was), MapSet.new(now))
  end

  defp group_added?(_was, _now), do: false

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
