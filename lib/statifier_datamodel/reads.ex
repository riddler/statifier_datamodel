defmodule StatifierDatamodel.Reads do
  @moduledoc """
  ADR-0004 decision 6: the read check over reads handed in as data.

  A chart's conditions read paths: `_event.data.due_on` on a transition
  taken on `loan.renewed`, or `loan.copy_id` from the chart's own data.
  `undeclared/2` is given a datamodel document and a list of those reads,
  and answers the ones the document does not declare, each with why.

  This package never parses an expression and takes no dependency to do so.
  The paths come from the expression language: a host lists the reads of
  each condition with `Predicator.Analysis.references/1`, adds the event
  names the condition is read under and a location of its own, and hands
  the list in. The how-to guide "Check the paths a chart's conditions read"
  shows the few lines that takes.

  ## A read

  A read is a map of three keys:

    * `events` - the event names the condition is read under: a
      transition's event descriptors, `[]` for a condition no event guards;
    * `path` - the path the condition reads, in
      `Predicator.Analysis.references/1`'s form: each segment a string, an
      integer for a literal index, or `:dynamic` for a computed key;
    * `location` - anything the host wants back. The check never reads it.

  ## The rules

    1. **A read rooted at `_event` whose second segment is `data`** is
       checked against the payload type of every declared event its names
       match. A read under several names must be declared on each event
       they match.
    2. **An event name matches as SCXML matches a descriptor**: a declared
       name equal to it, or one it is a token prefix of (`loan` matches
       `loan.renewed`, `loan.re` does not), and `*` matches every declared
       event. A name ending `.*` matches as the name without it does.
    3. **The `_event` system fields are not payload reads.** A read of
       `_event` alone, or of `name`, `type`, `sendid`, `origin`,
       `origintype` or `invokeid` under it, is skipped. Any other field
       under `_event` is one no event carries, and is reported on every
       event the read's names match.
    4. **A path beneath `_event.data` is declared when each segment is.** A
       string names a field of a declared record or shape and continues with
       that field's type; an integer descends a `list` into its `item_type`.
       A type that is unknown - a name the document does not declare, which
       includes a field type indexed `nil` - declares whatever lies beneath
       it, and so does a `list` whose item type is unknown. `object` and the
       other scalars declare no member.
    5. **A `:dynamic` segment ends the checked prefix there.** What follows a
       computed key is not checked.
    6. **A read whose names match no declared event is reported as such.**
    7. **Any other root is checked against the declared paths, and only when
       the document declares one.** The read's string segments, up to the
       first that is not a string, joined with `.`, must be in
       `StatifierDatamodel.Document.declared_paths/1`'s set. A document
       declaring no path reports nothing for such a read.

  An input that is not a datamodel document - one
  `StatifierDatamodel.Index.index/1` does not admit - has nothing to check a
  read against, and reports nothing.

  ## The answer

  `{read, reason}` pairs, in the order the reads came in, the read exactly
  as it was handed in. `reason` is one of three:

    * `:no_declared_event` - the read is under `_event` and its names match
      no event the document declares;
    * `{:undeclared, event_name, prefix}` - the payload of the declared
      event `event_name` does not declare the path; `prefix` is the read's
      path up to and including the first segment that is not declared. A
      read under names matching several events carries one pair for each
      event it fails on, in the document's `events` order;
    * `{:undeclared_path, prefix}` - a read of another root that the
      declared paths do not hold; `prefix` is the checked prefix, the read's
      string segments up to the first that is not a string.

  A read that is declared, skipped or not a read at all is not in the
  answer.

  ## Advisory, never a gate

  Every answer is a fact. Nothing refuses a document and nothing raises;
  whether a reported read stops a host's pipeline is the host's to decide
  (ADR-0001 decision 12).
  """

  alias StatifierDatamodel.{Declarations, Document, Events, Index, Types}

  @typedoc """
  One step of a path, in `Predicator.Analysis.references/1`'s form: a name,
  a literal integer index, or `:dynamic` for a computed key.
  """
  @type segment :: String.t() | integer() | :dynamic

  @typedoc """
  One read a condition makes: the event names it is read under, the path it
  reads, and a location the check passes back untouched.
  """
  @type read :: %{events: [String.t()], path: [segment()], location: term()}

  @typedoc "Why a read is reported."
  @type reason ::
          :no_declared_event
          | {:undeclared, String.t(), [segment()]}
          | {:undeclared_path, [String.t()]}

  # SCXML's `_event` fields beside `data`; a read of one is not a payload read.
  @system_fields ~w(name type sendid origin origintype invokeid)

  @doc """
  The reads `document` does not declare, in input order, each paired with
  why.

  The library loan. The document declares two local paths and the payloads
  of the two events a loan chart receives:

      iex> alias StatifierDatamodel.Reads
      iex> document = %{
      ...>   "version" => 1,
      ...>   "scopes" => [%{"scope" => "local", "entries" => [
      ...>     %{"name" => "copy_id", "path" => "loan.copy_id", "type" => "string"},
      ...>     %{"name" => "due_on", "path" => "loan.due_on", "type" => "date"}]}],
      ...>   "types" => [
      ...>     %{"name" => "loans.renewal", "kind" => "record", "fields" => [
      ...>       %{"name" => "copy_id", "type" => "string", "required?" => true},
      ...>       %{"name" => "due_on", "type" => "date", "required?" => true}]},
      ...>     %{"name" => "loans.return", "kind" => "record", "fields" => [
      ...>       %{"name" => "copy_id", "type" => "string", "required?" => true},
      ...>       %{"name" => "returned_at", "type" => "datetime", "required?" => true}]}],
      ...>   "events" => [
      ...>     %{"name" => "loan.renewed", "type" => "loans.renewal"},
      ...>     %{"name" => "loan.returned", "type" => "loans.return"}]}
      iex> Reads.undeclared(document, [
      ...>   %{events: ["loan.renewed"], path: ["_event", "data", "due_on"], location: 1},
      ...>   %{events: ["loan"], path: ["_event", "data", "due_on"], location: 2},
      ...>   %{events: ["patron.registered"], path: ["_event", "data", "patron_id"], location: 3},
      ...>   %{events: ["loan.renewed"], path: ["_event", "name"], location: 4},
      ...>   %{events: [], path: ["loan", "due_on"], location: 5},
      ...>   %{events: [], path: ["loan", "fine_cents"], location: 6}])
      [
        {%{events: ["loan"], path: ["_event", "data", "due_on"], location: 2},
         {:undeclared, "loan.returned", ["_event", "data", "due_on"]}},
        {%{events: ["patron.registered"], path: ["_event", "data", "patron_id"], location: 3},
         :no_declared_event},
        {%{events: [], path: ["loan", "fine_cents"], location: 6},
         {:undeclared_path, ["loan", "fine_cents"]}}
      ]

  A computed key ends what is checked, and a document that declares no path
  checks no other root:

      iex> alias StatifierDatamodel.Reads
      iex> document = %{"scopes" => [],
      ...>   "events" => [%{"name" => "loan.renewed", "type" => "object"}]}
      iex> Reads.undeclared(document, [
      ...>   %{events: ["loan.renewed"], path: ["_event", "data", :dynamic, "title"], location: nil},
      ...>   %{events: ["loan.renewed"], path: ["_event", "data", "title"], location: nil},
      ...>   %{events: [], path: ["loan", "fine_cents"], location: nil}])
      [{%{events: ["loan.renewed"], path: ["_event", "data", "title"], location: nil},
        {:undeclared, "loan.renewed", ["_event", "data", "title"]}}]
  """
  @spec undeclared(term(), [read()]) :: [{read(), reason()}]
  def undeclared(document, reads) when is_list(reads) do
    case Index.index(document) do
      nil ->
        []

      _index ->
        context = %{
          declarations: Declarations.from_document(document),
          events: Events.from_document(document).events,
          declared_paths: Document.declared_paths(document)
        }

        Enum.flat_map(reads, fn read ->
          read |> reasons(context) |> Enum.map(&{read, &1})
        end)
    end
  end

  def undeclared(_document, _not_a_list), do: []

  # -- one read ----------------------------------------------------------------

  @spec reasons(term(), map()) :: [reason()]
  defp reasons(%{path: ["_event" | rest] = path} = read, context) do
    event_reasons(rest, path, Map.get(read, :events), context)
  end

  defp reasons(%{path: path}, context) when is_list(path) do
    path_reasons(path, context.declared_paths)
  end

  defp reasons(_not_a_read, _context), do: []

  # Rules 1 to 6: a read under `_event`.
  @spec event_reasons([term()], [term()], term(), map()) :: [reason()]
  defp event_reasons([field | _rest], _path, _names, _context) when field in @system_fields,
    do: []

  defp event_reasons([field | rest], path, names, context)
       when is_binary(field) or is_integer(field) do
    case matching(names, context.events) do
      [] ->
        [:no_declared_event]

      entries ->
        Enum.flat_map(entries, &entry_reasons(&1, field, rest, path, context.declarations))
    end
  end

  # `_event` alone, or `_event` then a computed key: nothing to check.
  defp event_reasons(_alone_or_dynamic, _path, _names, _context), do: []

  # The reason one matched event gives a read beneath `_event`, if any; the
  # prefix runs to the first segment the event's payload does not declare.
  @spec entry_reasons(Events.entry(), term(), [term()], [term()], Declarations.t()) ::
          [reason()]
  defp entry_reasons(entry, field, rest, path, declarations) do
    case event_failure(field, rest, entry.type, declarations) do
      :declared -> []
      {:undeclared, depth} -> [{:undeclared, entry.name, Enum.take(path, depth + 2)}]
    end
  end

  # Whether the payload type declares the read beneath `_event`:
  # `{:undeclared, n}` when the n-th segment past `_event.data` is the first
  # not declared, and `{:undeclared, 0}` for a field other than `data`, which
  # no event carries.
  @spec event_failure(term(), [term()], Types.t(), Declarations.t()) ::
          :declared | {:undeclared, non_neg_integer()}
  defp event_failure("data", rest, type, declarations),
    do: descend(entry_type(type), rest, declarations, 0)

  defp event_failure(_not_data, _rest, _type, _declarations), do: {:undeclared, 0}

  # Rule 7: any other root, against the declared paths.
  @spec path_reasons([term()], MapSet.t(String.t()) | nil) :: [reason()]
  defp path_reasons(path, declared_paths) do
    prefix = Enum.take_while(path, &is_binary/1)

    cond do
      prefix == [] -> []
      declared_paths == nil or MapSet.size(declared_paths) == 0 -> []
      MapSet.member?(declared_paths, Enum.join(prefix, ".")) -> []
      true -> [{:undeclared_path, prefix}]
    end
  end

  # -- matching an event name ------------------------------------------------

  # The declared events the read's names match, in the document's order.
  @spec matching(term(), [Events.entry()]) :: [Events.entry()]
  defp matching(names, entries) when is_list(names) do
    descriptors = for name <- names, is_binary(name), do: descriptor(name)
    Enum.filter(entries, fn entry -> Enum.any?(descriptors, &matches?(&1, entry.name)) end)
  end

  defp matching(_not_a_list, _entries), do: []

  # SCXML reads `loan.*` as `loan`.
  @spec descriptor(String.t()) :: String.t()
  defp descriptor(name) do
    if String.ends_with?(name, ".*"), do: String.slice(name, 0..-3//1), else: name
  end

  @spec matches?(String.t(), String.t()) :: boolean()
  defp matches?("*", _declared), do: true
  defp matches?(name, name), do: true
  defp matches?(name, declared), do: String.starts_with?(declared, name <> ".")

  # -- descending a payload type -----------------------------------------------

  # A type as the descent reads it: a `list` carries its item type, unknown
  # when it has none.
  @spec entry_type(Types.t() | nil) :: term()
  defp entry_type(:list), do: {:list, nil}
  defp entry_type(type), do: type

  # Whether `type` declares `path`: `:declared`, or `{:undeclared, n}` naming
  # the first segment (counted from 1) it does not.
  @spec descend(term(), [term()], Declarations.t(), non_neg_integer()) ::
          :declared | {:undeclared, pos_integer()}
  defp descend(_type, [], _declarations, _depth), do: :declared

  # A computed key, or anything that is not a name or an index, ends the
  # checked prefix.
  defp descend(_type, [segment | _rest], _declarations, _depth)
       when not is_binary(segment) and not is_integer(segment),
       do: :declared

  defp descend(type, [segment | rest], declarations, depth) do
    case step(type, segment, declarations) do
      {:ok, :anything} -> :declared
      {:ok, next} -> descend(next, rest, declarations, depth + 1)
      :error -> {:undeclared, depth + 1}
    end
  end

  # One segment beneath `type`: `{:ok, :anything}` when the type is unknown
  # and declares whatever lies beneath it, `{:ok, type}` for the segment's
  # own type, `:error` when the type does not declare the segment.
  @spec step(term(), String.t() | integer(), Declarations.t()) ::
          {:ok, term()} | :error
  defp step(type, _segment, _declarations) when type in [nil, :unknown], do: {:ok, :anything}
  defp step({:opaque, _spelling}, _segment, _declarations), do: {:ok, :anything}

  defp step({:declared, name}, segment, declarations) do
    case Declarations.fetch(declarations, name) do
      {:ok, declaration} -> field(declaration.fields, segment)
      :error -> {:ok, :anything}
    end
  end

  defp step({:shape, members}, segment, _declarations) when is_list(members),
    do: field(members, segment)

  defp step({:list, item_type}, index, _declarations) when is_integer(index) do
    case item_type do
      known when known not in [nil, :unknown] -> {:ok, entry_type(known)}
      _unknown -> {:ok, :anything}
    end
  end

  defp step(_scalar_or_object, _segment, _declarations), do: :error

  @spec field([map()], String.t() | integer()) :: {:ok, term()} | :error
  defp field(fields, name) when is_binary(name) do
    case Enum.find(fields, &match?(%{name: ^name}, &1)) do
      nil -> :error
      found -> {:ok, field_type(found)}
    end
  end

  defp field(_fields, _index), do: :error

  # A field's type as the descent reads it, a `list` field carrying its item
  # type; a field with no type is unknown.
  @spec field_type(map()) :: term()
  defp field_type(%{type: :list} = list_field), do: {:list, Map.get(list_field, :item_type)}
  defp field_type(found), do: Map.get(found, :type)
end
