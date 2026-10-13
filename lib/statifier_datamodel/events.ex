defmodule StatifierDatamodel.Events do
  @moduledoc """
  The index over a datamodel document's `events` and `sends` keys
  (ADR-0004 decisions 1-5): per event name, the type of its payload.

  `events` declares the events a chart receives, by name, and the type of
  each one's payload - the value a chart's conditions read under
  `_event.data`. `sends` declares the events a chart sends, by name, and the
  type of the payload each carries. Both keys are optional: a document
  without either declares no events or no sends, which is the state every
  document written before the two keys existed is in.

  `from_document/1` is the index. It reads `events`, `sends` and, to resolve
  each entry's type, `types`; nothing else. So a caller asking *is this a
  datamodel document at all* asks `StatifierDatamodel.Index.index/1`, which
  is where that question is answered, and `index/1` does not read either key:
  every answer it gives is the answer it gave before the keys existed.

  ## An entry: `name` and `type` required

  An entry carries `name` (the event name as a chart spells it) and `type`
  (the payload's type), each a non-empty string, and the optional `label`
  (what a pane renders) and `note` (prose for a reader, carrying no
  contract). An entry missing `name` or `type`, or carrying either as
  anything but a non-empty string, declares nothing: it is dropped rather
  than raised on, and the rest of the list is indexed around it - ADR-0001
  decision 6's posture for a half-written declaration. A `label` or `note`
  that is not a string is `nil`.

  Each list keeps its own order, and a repeated `name` keeps its first
  occurrence, as `types` does. The two lists are separate: a name may appear
  in both, and an entry of one never shadows an entry of the other.

  ## A type resolves, or it is unknown

  `type` is one of the nine types the set is closed at, looked at first, or
  the `name` of a record or shape the `types` key declares, which is
  `{:declared, name}`. A spelling that names neither is `:unknown`: unknown,
  not wrong. There is no inline spelling: a `type` that is a map spelling a
  shape is not a string, so the entry declares nothing.

  ## Reported, never refused

  An entry whose type is `:unknown` stays in the index with that type, and
  `unresolved/1` lists the entries whose type resolves to nothing. A document
  with such an entry indexes and answers every other question exactly as it
  would without it; which unresolved entry matters to a host is the host's
  to decide (ADR-0001 decision 12).

  ## Not declared paths

  The two keys contribute no path to
  `StatifierDatamodel.Index.declared_paths/1` and nothing to
  `StatifierDatamodel.Index.path_types/1`, as `types` contributes none. The
  `event` scope is a different thing: one scope of paths every event carries,
  in the document's own addressing. An `events` entry declares one event's
  payload, read under `_event.data`, and the two do not overlap.
  """

  alias StatifierDatamodel.{Declarations, Types}

  @typedoc """
  One entry of `events` or `sends`, as indexed: its name, its payload's type
  expression (`:unknown` for a spelling that names nothing), and its label
  and note, each `nil` when the document gives no string.
  """
  @type entry :: %{
          name: String.t(),
          type: Types.t(),
          label: String.t() | nil,
          note: String.t() | nil
        }

  @typedoc "Each section in list order, the first occurrence of a name kept."
  @type t :: %{events: [entry()], sends: [entry()]}

  @typedoc "The two sections, by the key a document spells."
  @type section :: :events | :sends

  @sections [events: "events", sends: "sends"]

  @doc """
  Indexes a decoded datamodel document's `events` and `sends` keys.

  Total: every input has an answer and none of them raise. A document
  without the keys declares no events and no sends, and so does an input
  that is not a document.

      iex> alias StatifierDatamodel.Events
      iex> events = Events.from_document(%{
      ...>   "scopes" => [],
      ...>   "types" => [
      ...>     %{"name" => "loans.renewal", "kind" => "record", "label" => "Renewal",
      ...>       "fields" => [%{"name" => "due_on", "type" => "date", "required?" => true}]}],
      ...>   "events" => [
      ...>     %{"name" => "loan.renewed", "type" => "loans.renewal", "label" => "Loan renewed"},
      ...>     %{"name" => "loan.lost", "type" => "loans.loss"},
      ...>     %{"name" => "loan.renewed", "type" => "object"},
      ...>     %{"type" => "object", "label" => "No name"}],
      ...>   "sends" => [
      ...>     %{"name" => "patron.due_soon", "type" => "object", "note" => "Sent before the due date."}]})
      iex> Enum.map(events.events, &{&1.name, &1.type})
      [{"loan.renewed", {:declared, "loans.renewal"}}, {"loan.lost", :unknown}]
      iex> [notice] = events.sends
      iex> {notice.name, notice.type, notice.label, notice.note}
      {"patron.due_soon", :object, nil, "Sent before the due date."}

      iex> StatifierDatamodel.Events.from_document(%{"scopes" => []})
      %{events: [], sends: []}
      iex> StatifierDatamodel.Events.from_document(["loan.renewed"])
      %{events: [], sends: []}
  """
  @spec from_document(term()) :: t()
  def from_document(document) when is_map(document) do
    declarations = Declarations.from_document(document)

    Map.new(@sections, fn {section, key} ->
      {section, entries(Map.get(document, key), declarations)}
    end)
  end

  def from_document(_not_a_document), do: %{events: [], sends: []}

  @doc """
  The entry of `section` named `name`.

  `:error` for a name the section does not hold, for a section other than
  `:events` or `:sends`, and for anything that is not an index: an entry
  there would be a false claim.

      iex> alias StatifierDatamodel.Events
      iex> events = Events.from_document(%{"events" => [
      ...>   %{"name" => "loan.returned", "type" => "object", "label" => "Copy returned"}]})
      iex> {:ok, entry} = Events.fetch(events, :events, "loan.returned")
      iex> {entry.type, entry.label}
      {:object, "Copy returned"}
      iex> Events.fetch(events, :sends, "loan.returned")
      :error
      iex> Events.fetch(events, :events, "loan.lost")
      :error
  """
  @spec fetch(t(), section(), term()) :: {:ok, entry()} | :error
  def fetch(events, section, name)
      when is_map(events) and section in [:events, :sends] and is_binary(name) do
    case Map.get(events, section) do
      entries when is_list(entries) -> find(entries, name)
      _absent -> :error
    end
  end

  def fetch(_events, _section, _name), do: :error

  @doc """
  The entries whose type resolves to nothing, each section in its own list
  order.

  A fact, not a refusal: every entry listed here is still in the index, typed
  `:unknown`, and every other answer stands. Anything that is not an index
  lists nothing.

      iex> alias StatifierDatamodel.Events
      iex> events = Events.from_document(%{
      ...>   "events" => [
      ...>     %{"name" => "loan.renewed", "type" => "object"},
      ...>     %{"name" => "loan.lost", "type" => "loans.loss"}],
      ...>   "sends" => [%{"name" => "patron.due_soon", "type" => "notices.due_soon"}]})
      iex> unresolved = Events.unresolved(events)
      iex> {Enum.map(unresolved.events, & &1.name), Enum.map(unresolved.sends, & &1.name)}
      {["loan.lost"], ["patron.due_soon"]}
  """
  @spec unresolved(t()) :: t()
  def unresolved(events) when is_map(events) do
    Map.new(@sections, fn {section, _key} ->
      {section, events |> Map.get(section) |> unknown()}
    end)
  end

  def unresolved(_not_an_index), do: %{events: [], sends: []}

  # -- normalization ---------------------------------------------------------

  @spec entries(term(), Declarations.t()) :: [entry()]
  defp entries(raw, declarations) when is_list(raw) do
    raw
    |> Enum.flat_map(&entry(&1, declarations))
    |> Enum.uniq_by(& &1.name)
  end

  defp entries(_absent_or_malformed, _declarations), do: []

  @spec entry(term(), Declarations.t()) :: [entry()]
  defp entry(%{"name" => name, "type" => type} = raw, declarations)
       when is_binary(name) and name != "" and is_binary(type) and type != "" do
    [
      %{
        name: name,
        type: resolve(type, declarations),
        label: string(Map.get(raw, "label")),
        note: string(Map.get(raw, "note"))
      }
    ]
  end

  defp entry(_half_written, _declarations), do: []

  # One of the nine first, then a name the document declares; anything else
  # is unknown (ADR-0004 decision 3).
  @spec resolve(String.t(), Declarations.t()) :: Types.t()
  defp resolve(type, declarations) do
    case Types.scalar(type) do
      nil ->
        case Declarations.fetch(declarations, type) do
          {:ok, _declaration} -> {:declared, type}
          :error -> :unknown
        end

      scalar ->
        scalar
    end
  end

  @spec find([term()], String.t()) :: {:ok, entry()} | :error
  defp find(entries, name) do
    case Enum.find(entries, &match?(%{name: ^name}, &1)) do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  @spec unknown(term()) :: [entry()]
  defp unknown(entries) when is_list(entries) do
    Enum.filter(entries, &match?(%{type: :unknown}, &1))
  end

  defp unknown(_absent), do: []

  @spec string(term()) :: String.t() | nil
  defp string(value) when is_binary(value), do: value
  defp string(_other), do: nil
end
