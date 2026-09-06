defmodule StatifierDatamodel.Index do
  @moduledoc """
  The path/type index over a datamodel document (ADR-0001), and the
  projections that record promises.

  ADR-0001 decision 3 defines the document: a `version` plus three scopes -
  `global`, `local`, `event` - each carrying entries with `name`, `path`,
  `type` and `label`, plus the optional `fields`, `item_type`, `example`,
  `note`, `one_of` and `sensitive?`. Every path is absolute and globally
  addressable (an event entry spells its own `event.` prefix), and decision
  7 gives the one total function from the document to the declared-path
  set.

  This module is that record's reader. `index/1` admits a decoded document
  and flattens it to `path -> entry`, at every nesting depth; the lookups
  answer what a path's type is, what lies under a prefix, and whether a
  path is declared at all; `declared_paths/1` is decision 7's projection.

  ## Advisory, never a gate

  Decision 12 is the stance this module is built to keep: **an undeclared
  path is unknown, not wrong.** Nothing here returns a verdict, produces a
  finding, or refuses anything. `declared?/2` answers a question about the
  document, not about the author, and `type/2` returns `nil` for a path the
  document does not declare rather than an error - absence of a declaration
  is not a claim that the path is bad. Which of this module's facts is an
  error, which an advisory and which is silent is decided in a consumer's
  own record, argued on its own consumers.

  ## The admission step is `index/1`

  Decision 7 states its totality over *admitted* documents: a malformed
  input is a loader concern, rejected before that function is reached,
  which is why it has no `{:error, _}` arm to explain. `index/1` is that
  loader. It is itself total - an input it cannot admit returns `nil`, on
  the total-normalizer discipline the family uses everywhere - and every
  function taking a `t:t/0` is then total by construction.

  So the record's `declared_paths(document)` is spelled here as

      document |> index() |> declared_paths()

  with the `nil` case being *this input is not a datamodel document*, which
  is a different thing from *the document declares nothing*. That
  distinction is decision 6's, stated there for exactly the same pair of
  values: `nil` is no datamodel supplied, `MapSet.new()` is a host claim
  that nothing is declared.

  ## What normalization does, and what it declines to decide

  Keys are read as the record writes them, from a decoded JSON map with
  string keys.

    * **Scope names contribute nothing to a path** (decision 7), so a scope
      map naming something other than the three is not rejected: its
      entries are indexed with `scope: nil`. Paths are already absolute,
      and dropping entries over a scope label would lose declared paths
      the projection is required to contain.
    * **An entry whose `path` is not a non-empty string contributes no
      path**, and its `fields` are still walked. That is the only place
      this module departs from the projection's literal code, which would
      put a `nil` in the set; a set with a `nil` in it is not a set of
      declared paths, and the record admits no such entry in the first
      place.
    * **The type set is closed** (decision 4). A `type` or `item_type`
      outside it normalizes to `nil` - unknown, on the same stance as an
      undeclared path - rather than being carried through as a type this
      package would then be rendering.
    * **A repeated path keeps its first occurrence** in document order.
      This is not a ruling on the record's open question about collisions
      across scopes: the declared-path set is a set either way, and a
      document that needs the question answered needs a loader lint, which
      is where the record leaves it.
    * **`name` is read and stored, and nothing here consumes it.** The
      record carries an open question on how an event entry spells it; this
      module reads `path` alone for every derivation, exactly as the
      projection does, so the question stays open rather than being
      answered by use.

  ## An entry typed by a declaration

  Decision 3 as amended 2026-09-06 lets an entry's `type` - and a `list`
  entry's `item_type` - name a declaration the document's `types` key
  declares, instead of one of the nine. The reference is **nominal**: the
  entry's type is `{:declared, name}`, not a copy of the declaration's
  fields.

  Resolution is the closed set first and then `types`, the same precedence
  `StatifierDatamodel.Types.parse/2` uses for a declaration field, so a
  document that declares a type called `"string"` does not shadow the
  scalar. A spelling that names neither is `nil` - unknown, exactly as
  before.

  A declaration-typed entry then **expands**: it contributes its own path,
  and beneath it one path per field of the declaration, spelled
  `<entry path>.<field name>` at the entry's depth plus one, in the
  declaration's field order, recursively for a field that itself names a
  declaration. That is exactly what an inlined `object` entry does with its
  `fields`, which is the point - a host that spells the object out and a
  host that names the declaration get the same paths, so decision 7's
  projection and decision 11's are unchanged in their own terms.

  An expanded path carries what the field carries and nothing more: the
  field's `type`, `item_type`, `label` and `one_of`, its `name`, and the
  entry's `scope`. `example` and `note` are absent and `sensitive?` is
  `false`, because a declaration field has no such keys and this module does
  not invent them. An entry that names a declaration **and** carries
  `fields` contributes both, with the entry's own written-out `fields`
  ahead of the expansion, so a host that spells a path out gets the entry it
  wrote rather than the one derived from the declaration - first occurrence
  wins here as it does for a repeated path.

  A cycle between declarations is a document a host can write, and it
  discharges rather than recurring: a declaration already being expanded on
  the same chain is not expanded again, so `index/1` stays total. That is
  the discipline the read check already uses for a cyclic read.

  A `list` entry still contributes its own path alone whatever its
  `item_type` names: `item_type` names an element type, no record decides an
  index syntax, and there is no element path to expand.

  ## Value kinds, and why they are a third projection

  `path_types/1` is decision 11: the index projected to the expression
  language's own vocabulary of value kinds, which is a smaller and different
  set from the document's nine types. `integer` and `decimal` both answer
  `:number` there, because that is the distinction the expression language
  draws; `object` has no kind at all and neither does a `list` whose element
  type the document does not name, so those paths are simply absent.

  Absence is the same stance the rest of this module takes: an editor handed
  the map treats a path it does not contain exactly as it treats every path
  today, which is the reason this is a projection and not a check. The map
  carries no labels, scopes or declarations - a consumer wanting those reads
  the index it was built from.

  ## `sensitive?`, and why it is derived here rather than projected

  The entry map is where a per-path annotation lives, in the family's
  optional-boolean convention, and decision 7's projection **deliberately
  drops it**: a consumer that needs to know whether a path is sensitive
  reads the document, never the set.

  `sensitive_paths/1` is that read, and it is a second projection rather
  than a widening of the first: `declared_paths/1` returns paths and
  nothing else, exactly as decision 7 specifies. `datamodel/1` pairs the
  two into a `%{declared: MapSet, sensitive: MapSet}` map, so a host with a
  document reaches a sensitive-path pass without a second input.

  An entry's flag is read literally, per entry. An `object` entry marked
  sensitive does **not** stamp its fields, and does not need to: a
  sensitive-path matcher already treats a read of a prefix as a read of
  everything under it - a prefix read is the same leak spelled shorter - so
  inheritance here would restate the matcher and, where the two disagreed,
  would decide a rule no record has drawn.
  """

  alias StatifierDatamodel.Declarations

  @typedoc """
  The closed type set. No floats anywhere: money is integer minor units,
  and a `decimal`, a `datetime`, a `date` and a `duration` are all carried
  as strings.

  A `duration` value - and the `example` beside it - is a duration string
  the expression language reads, `30s` or `1h30m`, the same string an
  author types into a `:duration` field these paths feed. A `date` value is
  an ISO-8601 calendar date, `2026-09-05`, which is the spelling the
  expression language's own date literal reads. Which strings parse is the
  expression language's to define; this module stores whatever the document
  holds and parses none of it.

  These are the nine ADR-0001 decision 4 closes the set at: the eight the
  origin record closed it at, plus `date`. `date` is a distinct type and
  not a `datetime` because the expression language distinguishes them, and
  a projection that collapsed the two would offer the wrong operators.
  """
  @type type ::
          :string
          | :integer
          | :decimal
          | :boolean
          | :datetime
          | :duration
          | :date
          | :object
          | :list

  @typedoc "The record's three scopes, or `nil` for a scope map naming none of them."
  @type scope :: :global | :local | :event | nil

  @typedoc """
  A declared name used as a type: an entry's `type` or `item_type` may name
  a declaration the document's `types` key declares (decision 3 as amended
  2026-09-06), and the index carries the name rather than the declaration.
  """
  @type declared :: {:declared, String.t()}

  @typedoc """
  What an entry's `type` or `item_type` may be: one of the nine, or the name
  of a declaration.
  """
  @type entry_type :: type() | declared()

  @typedoc """
  One declared path, flattened out of the document.

  `depth` is the nesting level `fields` reached it at - `0` for a
  top-level entry - and is what a pane groups by when it renders an object
  and its members together.
  """
  @type entry :: %{
          path: String.t(),
          name: String.t() | nil,
          type: entry_type() | nil,
          label: String.t() | nil,
          scope: scope(),
          depth: non_neg_integer(),
          item_type: entry_type() | nil,
          example: term(),
          note: String.t() | nil,
          one_of: [term()] | nil,
          sensitive?: boolean()
        }

  @typedoc """
  The index: the document's `version`, its entries by path, the paths in
  document order, and the declarations the `types` key indexes to.

  The declarations are carried because resolving an entry's `type` needs
  them (decision 3 as amended 2026-09-06); they are
  `StatifierDatamodel.Declarations.from_document/1`'s answer over the same
  document, so a caller holding an index never builds a second one.
  """
  @type t :: %__MODULE__{
          version: integer(),
          entries: %{optional(String.t()) => entry()},
          order: [String.t()],
          declarations: Declarations.t()
        }

  defstruct version: 1, entries: %{}, order: [], declarations: %{}

  # The closed type set, and the three scopes, spelled as literal pairs
  # rather than converted: the record's sets are closed, so a closed match
  # is what reads them.
  @types %{
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

  @scopes %{"global" => :global, "local" => :local, "event" => :event}

  @doc """
  Admits a decoded datamodel document and indexes it, or returns `nil`.

  Total: every input has an answer and none of them raise. A map carrying
  a list under `"scopes"` is a document; anything else - a set, a list of
  paths, a bare map, a number - is not one, and gets `nil` rather than an
  empty index, so *not a document* stays distinguishable from *a document
  declaring nothing*.

      iex> alias StatifierDatamodel.Index
      iex> index = Index.index(%{"version" => 1, "scopes" => [
      ...>   %{"scope" => "local", "entries" => [
      ...>     %{"name" => "card", "path" => "card", "type" => "object", "label" => "Card",
      ...>       "fields" => [
      ...>         %{"name" => "brand", "path" => "card.brand", "type" => "string",
      ...>           "label" => "Brand"}]}]}]})
      iex> index.order
      ["card", "card.brand"]
      iex> Index.type(index, "card.brand")
      :string

      iex> StatifierDatamodel.Index.index(["card.brand"])
      nil
  """
  @spec index(term()) :: t() | nil
  def index(%{"scopes" => scopes} = document) when is_list(scopes) do
    declarations = Declarations.from_document(document)
    entries = Enum.flat_map(scopes, &scope_entries(&1, declarations))

    %__MODULE__{
      version: version(Map.get(document, "version")),
      entries: dedupe(entries),
      order: entries |> Enum.map(& &1.path) |> Enum.uniq(),
      declarations: declarations
    }
  end

  def index(_unrecognized), do: nil

  @doc """
  ADR-0001 decision 7's projection: every entry's own `path`, at every
  nesting depth, and nothing else.

  An `object` entry contributes its own path *and*, recursively, its
  fields'. A `list` entry contributes its own path alone - `item_type`
  names an element type and no record decides an index syntax, so there is
  no element path to contribute.

      iex> alias StatifierDatamodel.Index
      iex> %{"scopes" => [%{"scope" => "local", "entries" => [
      ...>   %{"path" => "risk_reasons", "type" => "list", "item_type" => "string"},
      ...>   %{"path" => "card", "type" => "object", "fields" => [%{"path" => "card.brand"}]}]}]}
      ...> |> Index.index()
      ...> |> Index.declared_paths()
      MapSet.new(["card", "card.brand", "risk_reasons"])
  """
  @spec declared_paths(t()) :: MapSet.t(String.t())
  def declared_paths(%__MODULE__{order: order}), do: MapSet.new(order)

  @doc """
  The declared paths the document annotates `sensitive?: true`.

  Read per entry and literally: an `object` marked sensitive does not
  stamp its fields. See the moduledoc for why that is a matcher's job
  rather than this one's.

      iex> alias StatifierDatamodel.Index
      iex> %{"scopes" => [%{"scope" => "local", "entries" => [
      ...>   %{"path" => "card.token_id", "type" => "string"},
      ...>   %{"path" => "card.number", "type" => "string", "sensitive?" => true}]}]}
      ...> |> Index.index()
      ...> |> Index.sensitive_paths()
      MapSet.new(["card.number"])
  """
  @spec sensitive_paths(t()) :: MapSet.t(String.t())
  def sensitive_paths(%__MODULE__{} = index) do
    index
    |> entries()
    |> Enum.filter(& &1.sensitive?)
    |> MapSet.new(& &1.path)
  end

  @doc """
  Both projections in one map, so a host that has a document supplies one
  input to a sensitive-path pass rather than two.

  Nothing in this package calls it; it is the derivation the record
  promised, at the shape a pass that would consume it already takes.
  """
  @spec datamodel(t()) :: %{declared: MapSet.t(String.t()), sensitive: MapSet.t(String.t())}
  def datamodel(%__MODULE__{} = index) do
    %{declared: declared_paths(index), sensitive: sensitive_paths(index)}
  end

  @typedoc """
  One value kind in the expression language's vocabulary.

  Six atoms, not nine: `integer` and `decimal` are both `:number`, and
  `object` and `list` have no kind of their own - a list is spelled
  `{:list, kind}` and an object is absent. `:list` is a value kind the
  expression language names too, but only ever inside that tuple here,
  since an element type the document does not give is not a list this
  projection can describe.
  """
  @type kind :: :string | :number | :boolean | :date | :datetime | :duration

  @typedoc """
  What one path projects to: a kind, a list of a kind, or an enumeration of
  the values an editor may draw as choices.
  """
  @type value_kind :: kind() | {:list, kind()} | {:one_of, [term()]}

  @doc """
  ADR-0001 decision 11's projection: `path -> value kind`, in the
  expression language's own vocabulary.

  Total, over anything: `nil` and a value that is not an index project to
  the empty map, on the same reasoning `index/1` returns `nil` for an
  input it cannot admit.

  Per entry, in the record's order:

    * a **drawable `one_of`** wins over the kind and gives
      `{:one_of, values}`. Drawable means every value can be rendered as a
      choice - a string, a number or a boolean. A `one_of` that is empty,
      or that holds anything else, is not drawn and the entry falls back to
      its kind. The enumeration winning is decision 11's word and is not
      qualified by the entry's type, so an `object` carrying a drawable
      `one_of` is present with its values, where the same entry without one
      would be absent.
    * `string` is `:string`; `integer` and `decimal` are both `:number`;
      `boolean` is `:boolean`; `date`, `datetime` and `duration` are
      themselves.
    * a `list` whose `item_type` is one of those is `{:list, kind}`.
    * `object`, a `list` with no usable `item_type`, and an entry whose
      type is outside the closed set are **absent from the map**. Absence
      means unknown, not wrong.

      iex> alias StatifierDatamodel.Index
      iex> %{"scopes" => [%{"scope" => "local", "entries" => [
      ...>   %{"path" => "amount_cents", "type" => "integer"},
      ...>   %{"path" => "risk_reasons", "type" => "list", "item_type" => "string"},
      ...>   %{"path" => "card", "type" => "object", "fields" => [
      ...>     %{"path" => "card.brand", "type" => "string",
      ...>       "one_of" => ["visa", "mastercard", "amex"]}]}]}]}
      ...> |> Index.index()
      ...> |> Index.path_types()
      %{
        "amount_cents" => :number,
        "risk_reasons" => {:list, :string},
        "card.brand" => {:one_of, ["visa", "mastercard", "amex"]}
      }

      iex> StatifierDatamodel.Index.path_types(nil)
      %{}
  """
  @spec path_types(t() | term()) :: %{optional(String.t()) => value_kind()}
  def path_types(%__MODULE__{} = index) do
    index
    |> entries()
    |> Enum.flat_map(fn entry ->
      case value_kind(entry) do
        nil -> []
        kind -> [{entry.path, kind}]
      end
    end)
    |> Map.new()
  end

  def path_types(_not_an_index), do: %{}

  @doc """
  Every entry, in document order.
  """
  @spec entries(t()) :: [entry()]
  def entries(%__MODULE__{entries: entries, order: order}) do
    Enum.map(order, &Map.fetch!(entries, &1))
  end

  @doc """
  The entry declared at `path`.

      iex> alias StatifierDatamodel.Index
      iex> index = Index.index(%{"scopes" => [
      ...>   %{"scope" => "local", "entries" => [%{"path" => "amount_cents", "type" => "integer"}]}]})
      iex> {:ok, entry} = Index.fetch(index, "amount_cents")
      iex> entry.type
      :integer
      iex> Index.fetch(index, "amount_dollars")
      :error
  """
  @spec fetch(t(), term()) :: {:ok, entry()} | :error
  def fetch(%__MODULE__{entries: entries}, path) when is_binary(path) do
    Map.fetch(entries, path)
  end

  def fetch(%__MODULE__{}, _path), do: :error

  @doc """
  The declared type of `path`, or `nil` when the document does not declare
  it - unknown, never wrong (decision 12).

  `nil` is also what a declared entry whose `type` is outside the closed
  set gets, for the same reason: this module reports what it can name and
  claims nothing about the rest.
  """
  @spec type(t(), term()) :: entry_type() | nil
  def type(%__MODULE__{} = index, path) do
    case fetch(index, path) do
      {:ok, entry} -> entry.type
      :error -> nil
    end
  end

  @doc """
  Whether the document declares `path`.

  A `false` here is *this document does not declare it*, which is the
  input to an advisory and to nothing that refuses anything.
  """
  @spec declared?(t(), term()) :: boolean()
  def declared?(%__MODULE__{} = index, path) do
    match?({:ok, _entry}, fetch(index, path))
  end

  @doc """
  Every entry strictly under `prefix`, at any depth, in document order -
  the completion query.

  The entry at `prefix` itself is not among them; `fetch/2` is how a
  caller asks about the prefix. A caller wanting one level only filters
  the result on `depth`.

      iex> alias StatifierDatamodel.Index
      iex> index = Index.index(%{"scopes" => [%{"scope" => "local", "entries" => [
      ...>   %{"path" => "card", "type" => "object", "fields" => [
      ...>     %{"path" => "card.brand"}, %{"path" => "card.last4"}]},
      ...>   %{"path" => "cardholder"}]}]})
      iex> index |> Index.under("card") |> Enum.map(& &1.path)
      ["card.brand", "card.last4"]
  """
  @spec under(t(), term()) :: [entry()]
  def under(%__MODULE__{} = index, prefix) when is_binary(prefix) and prefix != "" do
    index
    |> entries()
    |> Enum.filter(&String.starts_with?(&1.path, prefix <> "."))
  end

  def under(%__MODULE__{}, _prefix), do: []

  # -- value kinds -----------------------------------------------------------

  @spec value_kind(entry()) :: value_kind() | nil
  defp value_kind(entry) do
    case drawable(entry.one_of) do
      nil -> kind(entry)
      values -> {:one_of, values}
    end
  end

  # A list describes itself through its element type, so a list with no
  # usable one has no kind - `{:list, nil}` would be an editor rendering a
  # list of nothing.
  @spec kind(entry()) :: value_kind() | nil
  defp kind(%{type: :list, item_type: item_type}), do: wrap(scalar_kind(item_type))
  defp kind(%{type: type}), do: scalar_kind(type)

  @spec wrap(kind() | nil) :: {:list, kind()} | nil
  defp wrap(nil), do: nil
  defp wrap(kind), do: {:list, kind}

  # The nine, mapped onto the expression language's six. `object` and `list`
  # fall through: neither is a kind, and a nested list is not one either.
  @spec scalar_kind(type() | nil) :: kind() | nil
  defp scalar_kind(:string), do: :string
  defp scalar_kind(:integer), do: :number
  defp scalar_kind(:decimal), do: :number
  defp scalar_kind(:boolean), do: :boolean
  defp scalar_kind(:date), do: :date
  defp scalar_kind(:datetime), do: :datetime
  defp scalar_kind(:duration), do: :duration
  defp scalar_kind(_object_list_or_unknown), do: nil

  # The values an editor can render as choices, or `nil` when there is no
  # enumeration to draw.
  @spec drawable(term()) :: [term()] | nil
  defp drawable([_first | _rest] = values) do
    if Enum.all?(values, &drawable?/1), do: values, else: nil
  end

  defp drawable(_empty_or_absent), do: nil

  @spec drawable?(term()) :: boolean()
  defp drawable?(value), do: is_binary(value) or is_number(value) or is_boolean(value)

  # -- normalization ---------------------------------------------------------

  @spec version(term()) :: integer()
  defp version(v) when is_integer(v), do: v
  defp version(_absent_or_malformed), do: 1

  @spec scope_entries(term(), Declarations.t()) :: [entry()]
  defp scope_entries(%{"entries" => entries} = scope, declarations) when is_list(entries) do
    name = scope_name(Map.get(scope, "scope"))
    Enum.flat_map(entries, &entry(&1, declarations, name, 0))
  end

  defp scope_entries(_unrecognized, _declarations), do: []

  @spec scope_name(term()) :: scope()
  defp scope_name(name) when is_binary(name), do: Map.get(@scopes, name)
  defp scope_name(_other), do: nil

  # The projection's `entry_paths/1`, carrying the whole entry rather than
  # its path alone: an entry contributes itself when it has a path, and its
  # `fields` are walked either way.
  @spec entry(term(), Declarations.t(), scope(), non_neg_integer()) :: [entry()]
  defp entry(%{} = raw, declarations, scope, depth) do
    {own, expanded} =
      case Map.get(raw, "path") do
        path when is_binary(path) and path != "" ->
          normalized = normalize(raw, declarations, path, scope, depth)
          {[normalized], expand(normalized, declarations, MapSet.new())}

        _absent_or_malformed ->
          {[], []}
      end

    own ++ fields(Map.get(raw, "fields"), declarations, scope, depth + 1) ++ expanded
  end

  defp entry(_unrecognized, _declarations, _scope, _depth), do: []

  @spec fields(term(), Declarations.t(), scope(), non_neg_integer()) :: [entry()]
  defp fields(fields, declarations, scope, depth) when is_list(fields) do
    Enum.flat_map(fields, &entry(&1, declarations, scope, depth))
  end

  defp fields(_absent, _declarations, _scope, _depth), do: []

  # -- expanding a declaration-typed entry -----------------------------------

  # The declaration's fields, beneath the entry's own path, exactly as an
  # inlined `object` contributes its `fields`. `seen` carries the
  # declarations already being expanded on this chain of paths, so a cycle
  # discharges instead of recurring.
  @spec expand(entry(), Declarations.t(), MapSet.t(String.t())) :: [entry()]
  defp expand(%{type: {:declared, name}} = entry, declarations, seen) do
    with false <- MapSet.member?(seen, name),
         {:ok, declaration} <- Declarations.fetch(declarations, name) do
      seen = MapSet.put(seen, name)

      Enum.flat_map(declaration.fields, fn field ->
        member = member(entry, field)
        [member | expand(member, declarations, seen)]
      end)
    else
      _cyclic_or_undeclared -> []
    end
  end

  defp expand(_not_declaration_typed, _declarations, _seen), do: []

  # One field of a declaration, as the entry it contributes beneath its
  # parent. A declaration field has no `example` and no `note` and carries
  # no `sensitive?`, so this invents none of them.
  @spec member(entry(), Declarations.field()) :: entry()
  defp member(entry, field) do
    %{
      path: entry.path <> "." <> field.name,
      name: field.name,
      type: field.type,
      label: field.label,
      scope: entry.scope,
      depth: entry.depth + 1,
      item_type: field.item_type,
      example: nil,
      note: nil,
      one_of: field.one_of,
      sensitive?: false
    }
  end

  @spec normalize(map(), Declarations.t(), String.t(), scope(), non_neg_integer()) :: entry()
  defp normalize(raw, declarations, path, scope, depth) do
    %{
      path: path,
      name: string(Map.get(raw, "name")),
      type: entry_type(Map.get(raw, "type"), declarations),
      label: string(Map.get(raw, "label")),
      scope: scope,
      depth: depth,
      item_type: entry_type(Map.get(raw, "item_type"), declarations),
      example: Map.get(raw, "example"),
      note: string(Map.get(raw, "note")),
      one_of: list(Map.get(raw, "one_of")),
      sensitive?: Map.get(raw, "sensitive?") == true
    }
  end

  # The closed set first, so a declaration named for a scalar does not shadow
  # it, then the declarations; a spelling that names neither is unknown.
  @spec entry_type(term(), Declarations.t()) :: entry_type() | nil
  defp entry_type(t, declarations) when is_binary(t) do
    case Map.get(@types, t) do
      nil -> if Map.has_key?(declarations, t), do: {:declared, t}
      scalar -> scalar
    end
  end

  defp entry_type(_outside_the_closed_set, _declarations), do: nil

  @spec string(term()) :: String.t() | nil
  defp string(value) when is_binary(value), do: value
  defp string(_other), do: nil

  @spec list(term()) :: [term()] | nil
  defp list(value) when is_list(value), do: value
  defp list(_other), do: nil

  # First occurrence wins, so the index agrees with `order`.
  @spec dedupe([entry()]) :: %{optional(String.t()) => entry()}
  defp dedupe(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      Map.put_new(acc, entry.path, entry)
    end)
  end
end
