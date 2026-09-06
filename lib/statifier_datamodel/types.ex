defmodule StatifierDatamodel.Types do
  @moduledoc """
  Type expressions over a datamodel document, and ADR-0001 decision 8's read
  check.

  A **type expression** is one of four things, and the record admits no
  fifth:

    * `{:declared, name}` - a name the document's `types` key declares;
    * one of the nine types the set is closed at (`:string`, `:integer`,
      `:decimal`, `:boolean`, `:datetime`, `:duration`, `:date`, `:object`,
      `:list`);
    * `{:opaque, string}` - a string a consumer carries that names neither,
      which compares by identity and by nothing else;
    * `:unknown` - nothing is known about it.

  `parse/2` reads a document's spelling into one of those, in that order of
  precedence: the closed set first, so a document that declares a type
  called `"string"` does not shadow the scalar, and the declaration is still
  reachable by every other read. `to_string/1` prints one back for a pane.

  ## The read check

  `satisfies?/3` and `satisfies/3` decide whether a type `held` at a path
  can be read where a type `expected` is required, in the record's order:

    1. either side unknown -> satisfied (`:unknown`). Unknown is permissive
       both ways: this package's whole stance is that what the document does
       not say is not thereby wrong.
    2. identity -> satisfied (`:identical`). The same declared name, the same
       type from the closed set, or the same opaque string.
    3. `held` names a **record** and `expected` names a **shape** -> satisfied
       when the record's fields cover the shape's required set (`:covers`):
       for every field of the shape with `required?: true`, the record has a
       field of the same `name`, itself `required?: true`, whose type
       satisfies the shape field's type under this same check. Otherwise
       `{:missing, names}`, in the shape's own field order - a field the
       record does not have, a field the record declares optional, and a
       field whose type does not satisfy are the same failure, and all are
       named. A record field the shape does not name is ignored, and a shape
       field the shape marks optional is not consulted at all.
    4. otherwise -> `:not_assignable`.

  Step 3 reads both sides' `required?`, on decision 8 as amended
  2026-09-06. A record that declares a field optional has not promised the
  value, and a shape that marks the field required cannot proceed without
  it, so the record does not cover the shape. That failure carries the same
  `{:missing, names}` the absent field carries, and the vocabulary does not
  grow: *missing* means the record does not promise the field, whichever way
  it fails to. A consumer that needs to tell absent from present-but-optional
  reads the record's declaration for the named field; nothing this relation
  decides turns on the difference.

  That is the whole relation, and the shape of what it leaves out is the
  point. There is no record-into-record structural widening: identity is
  nominal, so two records with identical fields are two records. There is no
  union, no inference, and no host relation - a consumer that widens further
  by name, the palette's host relation in `statifier_blocks`, runs its own
  step after this one returns not-satisfied, in its own package.

  The check compares a field's `type`, which is what the record says. A
  `list` field's `item_type` is carried by
  `t:StatifierDatamodel.Declarations.field/0` and is not descended into
  here: `list` satisfies `list`, whatever the two elements are. Narrowing
  that is a decision no record has taken.

  Declarations may reference each other, and a cycle between them is a
  document a host can write. The check is total over one anyway: a pair of
  names already being decided further up the same check is treated as
  satisfied rather than re-entered, so an obligation never depends on
  itself twice.
  """

  import Kernel, except: [to_string: 1]

  alias StatifierDatamodel.Declarations

  @typedoc """
  A type expression: a declared name, one of the nine, an opaque string a
  consumer carries, or unknown.
  """
  @type t ::
          {:declared, String.t()}
          | StatifierDatamodel.Index.type()
          | {:opaque, String.t()}
          | :unknown

  @typedoc """
  Why a read is satisfied, or why it is not - the same check as
  `satisfies?/3`, for a consumer that renders the reason.
  """
  @type reason ::
          :unknown
          | :identical
          | :covers
          | {:missing, [String.t()]}
          | :not_assignable

  # ADR-0001 decision 4's closed set, by the spelling a document writes. The
  # set is the record's, and `StatifierDatamodel.Index` closes entry types at
  # the same nine; the two agreeing is asserted in the tests rather than
  # assumed, since a widening that reached one and not the other would be a
  # document that indexed differently from the way it type-checks.
  @scalars %{
    "string" => :string,
    "integer" => :integer,
    "decimal" => :decimal,
    "boolean" => :boolean,
    "datetime" => :datetime,
    "duration" => :duration,
    "date" => :date,
    "object" => :object,
    "list" => :list
  }

  @grammar_atoms [:unknown | Map.values(@scalars)]

  @doc """
  The type in the closed set that `spelling` names, or `nil`.

  The closed-set half of the grammar, on its own, for a caller resolving a
  document's spellings before the declarations are known -
  `StatifierDatamodel.Declarations` resolves a field's type with it.

      iex> StatifierDatamodel.Types.scalar("date")
      :date
      iex> StatifierDatamodel.Types.scalar("cards.card")
      nil
      iex> StatifierDatamodel.Types.scalar(7)
      nil
  """
  @spec scalar(term()) :: t() | nil
  def scalar(spelling) when is_binary(spelling), do: Map.get(@scalars, spelling)
  def scalar(_outside_the_closed_set), do: nil

  @doc """
  Reads a document's spelling of a type into a type expression.

  Total. The closed set is looked at first, then the declarations; a
  non-empty string that names neither is opaque, and anything that is not a
  non-empty string is `:unknown`.

      iex> alias StatifierDatamodel.{Declarations, Types}
      iex> declarations = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "label" => "Card", "fields" => []}]})
      iex> Types.parse(declarations, "integer")
      :integer
      iex> Types.parse(declarations, "cards.card")
      {:declared, "cards.card"}
      iex> Types.parse(declarations, "Settleable")
      {:opaque, "Settleable"}
      iex> Types.parse(declarations, nil)
      :unknown
  """
  @spec parse(Declarations.t(), term()) :: t()
  def parse(declarations, spelling) when is_binary(spelling) and spelling != "" do
    case scalar(spelling) do
      nil ->
        case Declarations.fetch(declarations, spelling) do
          {:ok, _declaration} -> {:declared, spelling}
          :error -> {:opaque, spelling}
        end

      scalar ->
        scalar
    end
  end

  def parse(_declarations, _absent_or_malformed), do: :unknown

  @doc """
  Prints a type expression the way a document spells it.

  For a pane that renders a type beside a path. It is a rendering and not an
  identity: `:unknown` prints as `"unknown"`, which an opaque string is free
  to spell too, and `parse/2` is the only reader of a document's spelling.

      iex> alias StatifierDatamodel.Types
      iex> Types.to_string({:declared, "cards.credit_txn"})
      "cards.credit_txn"
      iex> Types.to_string(:datetime)
      "datetime"
      iex> Types.to_string({:opaque, "Settleable"})
      "Settleable"
      iex> Types.to_string(:unknown)
      "unknown"
  """
  @spec to_string(t()) :: String.t()
  def to_string({:declared, name}) when is_binary(name), do: name
  def to_string({:opaque, name}) when is_binary(name), do: name
  def to_string(type) when is_atom(type), do: Atom.to_string(type)

  @doc """
  Whether a value of type `held` may be read where `expected` is required.

  ADR-0001 decision 8, as `satisfies/3` decides it: true for `:unknown`,
  `:identical` and `:covers`, false for `{:missing, _}` and
  `:not_assignable`.

      iex> alias StatifierDatamodel.{Declarations, Types}
      iex> declarations = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.credit_txn", "kind" => "record", "label" => "Credit transaction",
      ...>     "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]},
      ...>   %{"name" => "Settleable", "kind" => "shape", "label" => "Settleable",
      ...>     "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]}]})
      iex> Types.satisfies?(declarations, {:declared, "cards.credit_txn"}, {:declared, "Settleable"})
      true
      iex> Types.satisfies?(declarations, :integer, :string)
      false
  """
  @spec satisfies?(Declarations.t(), t(), t()) :: boolean()
  def satisfies?(declarations, held, expected) do
    case satisfies(declarations, held, expected) do
      :unknown -> true
      :identical -> true
      :covers -> true
      _not_satisfied -> false
    end
  end

  @doc """
  The read check, returning the reason.

  A `{:declared, name}` naming nothing this document declares is `:unknown`,
  which is the same normalization the index gives a reference to an
  undeclared name; the four steps then run over what is left.

      iex> alias StatifierDatamodel.{Declarations, Types}
      iex> declarations = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.credit_txn", "kind" => "record", "label" => "Credit transaction",
      ...>     "fields" => [
      ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
      ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => true}]},
      ...>   %{"name" => "Refundable", "kind" => "shape", "label" => "Refundable",
      ...>     "fields" => [
      ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
      ...>       %{"name" => "settled_at", "type" => "datetime", "required?" => true}]}]})
      iex> Types.satisfies(declarations, {:declared, "cards.credit_txn"}, {:declared, "Refundable"})
      {:missing, ["settled_at"]}
      iex> Types.satisfies(declarations, :date, :date)
      :identical
      iex> Types.satisfies(declarations, {:declared, "cards.credit_txn"}, :unknown)
      :unknown

  A field the record declares optional is missing from the read the same way
  an absent one is: the record has not promised the value, and the shape
  requires it.

      iex> alias StatifierDatamodel.{Declarations, Types}
      iex> optional_authorized_at = fn required? -> Declarations.from_document(%{"types" => [
      ...>   %{"name" => "cards.credit_txn", "kind" => "record", "label" => "Credit transaction",
      ...>     "fields" => [
      ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
      ...>       %{"name" => "currency", "type" => "string", "required?" => true},
      ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => required?}]},
      ...>   %{"name" => "Settleable", "kind" => "shape", "label" => "Settleable",
      ...>     "fields" => [
      ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
      ...>       %{"name" => "currency", "type" => "string", "required?" => true},
      ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => true}]}]}) end
      iex> Types.satisfies(optional_authorized_at.(false), {:declared, "cards.credit_txn"}, {:declared, "Settleable"})
      {:missing, ["authorized_at"]}
      iex> Types.satisfies(optional_authorized_at.(true), {:declared, "cards.credit_txn"}, {:declared, "Settleable"})
      :covers
  """
  @spec satisfies(Declarations.t(), t(), t()) :: reason()
  def satisfies(declarations, held, expected) do
    decide(
      declarations,
      resolve(declarations, held),
      resolve(declarations, expected),
      MapSet.new()
    )
  end

  # -- the four steps --------------------------------------------------------

  @spec decide(Declarations.t(), t(), t(), MapSet.t({String.t(), String.t()})) :: reason()
  defp decide(_declarations, :unknown, _expected, _seen), do: :unknown
  defp decide(_declarations, _held, :unknown, _seen), do: :unknown
  defp decide(_declarations, same, same, _seen), do: :identical

  defp decide(declarations, {:declared, held}, {:declared, expected}, seen) do
    pair = {held, expected}

    # A pair already being decided further up this same check is a cyclic
    # reference: it discharges rather than being re-entered.
    if MapSet.member?(seen, pair) do
      :covers
    else
      covers(
        declarations,
        Map.fetch!(declarations, held),
        Map.fetch!(declarations, expected),
        MapSet.put(seen, pair)
      )
    end
  end

  defp decide(_declarations, _held, _expected, _seen), do: :not_assignable

  # Step 3: a record read as a shape, and nothing else.
  @spec covers(
          Declarations.t(),
          Declarations.declaration(),
          Declarations.declaration(),
          MapSet.t({String.t(), String.t()})
        ) :: reason()
  defp covers(declarations, %{kind: :record, fields: held}, %{kind: :shape} = shape, seen) do
    by_name = Map.new(held, &{&1.name, &1})

    missing =
      for field <- shape.fields,
          field.required?,
          not covered?(declarations, Map.get(by_name, field.name), field, seen),
          do: field.name

    case missing do
      [] -> :covers
      names -> {:missing, names}
    end
  end

  defp covers(_declarations, _held, _expected, _seen), do: :not_assignable

  @spec covered?(
          Declarations.t(),
          Declarations.field() | nil,
          Declarations.field(),
          MapSet.t({String.t(), String.t()})
        ) :: boolean()
  defp covered?(_declarations, nil, _required, _seen), do: false

  # An optional record field does not promise the value, so it does not cover
  # a required shape field - the same failure as an absent one, and named the
  # same way (decision 8 as amended 2026-09-06).
  defp covered?(_declarations, %{required?: false}, _required, _seen), do: false

  defp covered?(declarations, held, required, seen) do
    decide(declarations, field_type(held), field_type(required), seen) in [
      :unknown,
      :identical,
      :covers
    ]
  end

  # A field whose type resolved to nothing is unknown, and unknown is
  # permissive both ways.
  @spec field_type(Declarations.field()) :: t()
  defp field_type(%{type: nil}), do: :unknown
  defp field_type(%{type: type}), do: type

  # A declared name this document does not declare is unknown; anything
  # outside the grammar is unknown too, which is what keeps the check total.
  @spec resolve(Declarations.t(), term()) :: t()
  defp resolve(declarations, {:declared, name} = type) when is_binary(name) do
    case Declarations.fetch(declarations, name) do
      {:ok, _declaration} -> type
      :error -> :unknown
    end
  end

  defp resolve(_declarations, {:opaque, name} = type) when is_binary(name), do: type

  defp resolve(_declarations, type) when type in @grammar_atoms, do: type

  defp resolve(_declarations, _outside_the_grammar), do: :unknown
end
