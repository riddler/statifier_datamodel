defmodule StatifierDatamodel.Declarations do
  @moduledoc """
  The index over a datamodel document's `types` key (ADR-0001 decision 5):
  the named record and shape declarations, by name.

  A declaration is a `name`, a `kind` - `record` or `shape` - a `label`, and
  an ordered list of fields. A **record** is a fact about what a write puts
  at a path; a **shape** is a constraint a read places on a path. Identity
  is nominal: two records with identical fields are two records. The one
  widening between them is the read check, which is
  `StatifierDatamodel.Types`'.

  `from_document/1` is the index. It reads the `types` key and nothing else,
  so a caller asking *is this a datamodel document at all* asks
  `StatifierDatamodel.Index.index/1`, which is where that question is
  answered; a document without the key declares no types, and so does an
  input that is not a document.

  ## A half-written declaration declares nothing

  Decision 6's addition, kept literally: a declaration missing `name`, `kind`
  or `fields`, or whose `kind` is neither `record` nor `shape`, is dropped
  rather than raised on, and the rest of the list is indexed around it.
  `label` is not among those keys - the record's own type for a declaration
  carries `label: String.t() | nil` - so a declaration with no usable label
  still declares its fields, and a pane renders the name it has.

  A repeated name keeps its first occurrence, in list order, which is the
  rule `StatifierDatamodel.Index` already uses for a repeated path.

  ## A field's type resolves, or it is unknown

  A field carries `name`, `type`, and the optional `required?` (default
  `false`), `label` and `one_of`; a `list` field carries `item_type` under
  the same rule. A field's type is one of the nine types the index closes
  the set at, or the `name` of another declaration - resolved against the
  whole list, so declarations may reference each other in either order. A
  reference to a name the list does not declare is `nil`: unknown, on the
  same stance an undeclared path gets, rather than a failed admission.

  A field with no usable `name` contributes nothing - it can neither be
  covered nor named in a coverage failure - and a repeated field name keeps
  its first occurrence, for the same reason a repeated path does.

  `note` is read by nobody: the record gives it to a human reader and says
  it carries no contract, and the record's own type for a declaration and
  for a field carries no `note` key. It is left in the document.
  """

  alias StatifierDatamodel.Types

  @typedoc """
  One field of a declaration, normalized.

  `type` and `item_type` are type expressions (`t:StatifierDatamodel.Types.t/0`),
  or `nil` for a spelling that names neither a type in the closed set nor a
  declaration in this document.
  """
  @type field :: %{
          name: String.t(),
          type: Types.t() | nil,
          item_type: Types.t() | nil,
          required?: boolean(),
          label: String.t() | nil,
          one_of: [term()] | nil
        }

  @typedoc "One declaration: a nominal name, its kind, its label and its ordered fields."
  @type declaration :: %{
          name: String.t(),
          kind: :record | :shape,
          label: String.t() | nil,
          fields: [field()]
        }

  @typedoc "The declarations of one document, by name."
  @type t :: %{optional(String.t()) => declaration()}

  @kinds %{"record" => :record, "shape" => :shape}

  @doc """
  Indexes a decoded datamodel document's `types` key to `name -> declaration`.

  Total: every input has an answer and none of them raise. A document
  without the key - the state every document written before the key existed
  is in - declares nothing, and so does an input that is not a document.

      iex> alias StatifierDatamodel.Declarations
      iex> declarations = Declarations.from_document(%{"scopes" => [], "types" => [
      ...>   %{"name" => "cards.card", "kind" => "record", "label" => "Card",
      ...>     "fields" => [%{"name" => "last4", "type" => "string", "required?" => true}]},
      ...>   %{"name" => "cards.credit_txn", "kind" => "record", "label" => "Credit transaction",
      ...>     "fields" => [%{"name" => "card", "type" => "cards.card", "required?" => true}]}]})
      iex> Map.keys(declarations) |> Enum.sort()
      ["cards.card", "cards.credit_txn"]
      iex> {:ok, txn} = Declarations.fetch(declarations, "cards.credit_txn")
      iex> txn.kind
      :record
      iex> [card] = txn.fields
      iex> {card.type, card.required?}
      {{:declared, "cards.card"}, true}

      iex> StatifierDatamodel.Declarations.from_document(%{"scopes" => []})
      %{}
      iex> StatifierDatamodel.Declarations.from_document(["cards.card"])
      %{}
  """
  @spec from_document(term()) :: t()
  def from_document(%{"types" => types}) when is_list(types) do
    names = names(types)

    types
    |> Enum.flat_map(&declaration(&1, names))
    |> Enum.reduce(%{}, fn declaration, acc ->
      Map.put_new(acc, declaration.name, declaration)
    end)
  end

  def from_document(_absent_or_not_a_document), do: %{}

  @doc """
  The declaration named `name`.

      iex> alias StatifierDatamodel.Declarations
      iex> declarations = Declarations.from_document(%{"types" => [
      ...>   %{"name" => "Settleable", "kind" => "shape", "label" => "Settleable",
      ...>     "fields" => [%{"name" => "amount_cents", "type" => "integer", "required?" => true}]}]})
      iex> {:ok, shape} = Declarations.fetch(declarations, "Settleable")
      iex> shape.kind
      :shape
      iex> Declarations.fetch(declarations, "Refundable")
      :error
  """
  @spec fetch(t(), term()) :: {:ok, declaration()} | :error
  def fetch(declarations, name) when is_map(declarations) and is_binary(name) do
    Map.fetch(declarations, name)
  end

  def fetch(declarations, _name) when is_map(declarations), do: :error

  # -- normalization ---------------------------------------------------------

  # The names the list declares, collected before any field is resolved, so a
  # declaration may reference one that appears after it.
  @spec names([term()]) :: MapSet.t(String.t())
  defp names(types) do
    for raw <- types, name = declared_name(raw), into: MapSet.new(), do: name
  end

  @spec declared_name(term()) :: String.t() | nil
  defp declared_name(%{"name" => name, "kind" => kind, "fields" => fields})
       when is_binary(name) and name != "" and is_list(fields) do
    if Map.has_key?(@kinds, kind), do: name
  end

  defp declared_name(_half_written), do: nil

  @spec declaration(term(), MapSet.t(String.t())) :: [declaration()]
  defp declaration(%{"fields" => fields} = raw, names) when is_list(fields) do
    case declared_name(raw) do
      nil ->
        []

      name ->
        [
          %{
            name: name,
            kind: Map.fetch!(@kinds, Map.get(raw, "kind")),
            label: string(Map.get(raw, "label")),
            fields: fields(fields, names)
          }
        ]
    end
  end

  defp declaration(_half_written, _names), do: []

  @spec fields([term()], MapSet.t(String.t())) :: [field()]
  defp fields(fields, names) do
    fields
    |> Enum.flat_map(&field(&1, names))
    |> Enum.uniq_by(& &1.name)
  end

  @spec field(term(), MapSet.t(String.t())) :: [field()]
  defp field(%{"name" => name} = raw, names) when is_binary(name) and name != "" do
    [
      %{
        name: name,
        type: field_type(Map.get(raw, "type"), names),
        item_type: field_type(Map.get(raw, "item_type"), names),
        required?: Map.get(raw, "required?") == true,
        label: string(Map.get(raw, "label")),
        one_of: list(Map.get(raw, "one_of"))
      }
    ]
  end

  defp field(_unnamed, _names), do: []

  # One of the nine, or a name this document declares; anything else is
  # unknown, which the record spells `nil` here.
  @spec field_type(term(), MapSet.t(String.t())) :: Types.t() | nil
  defp field_type(type, names) when is_binary(type) do
    case Types.scalar(type) do
      nil -> if MapSet.member?(names, type), do: {:declared, type}
      scalar -> scalar
    end
  end

  defp field_type(_absent_or_malformed, _names), do: nil

  @spec string(term()) :: String.t() | nil
  defp string(value) when is_binary(value), do: value
  defp string(_other), do: nil

  @spec list(term()) :: [term()] | nil
  defp list(value) when is_list(value), do: value
  defp list(_other), do: nil
end
