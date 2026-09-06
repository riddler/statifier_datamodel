defmodule StatifierDatamodel.Document do
  @moduledoc """
  The document-level reads: the three questions a consumer asks of a raw,
  decoded datamodel document rather than of an index it already holds.

  `StatifierDatamodel.Index` is the reader; this module is the shorthand
  over it, so that a consumer holding a document supplies one argument and
  never re-derives an index of its own. Each function here admits its
  argument through `StatifierDatamodel.Index.index/1` and answers totally
  for anything that admission declines - the same total-normalizer
  discipline the index is written under, reaching one more caller.

    * `declared_paths/1` - ADR-0001 decision 7's projection, over a
      document: the declared-path set, or `nil` for an input that is not a
      document.
    * `candidates_under/2` - the completion query: the declared paths
      strictly under a prefix, in the document's own order.
    * `declared_values/1` - the `one_of` enumerations the document
      declares, per path, for a picker that offers values rather than
      paths.

  What is deliberately not here: the shapes a consumer accepts *beside* a
  document. A host that also accepts a bare list of paths, a `MapSet`, or
  `nil`, and that folds a document into that same normalizer, owns the
  fold - the set it ends up with is that consumer's input contract, and
  this package answers only for the document half of it.

  ## Advisory, never a gate

  Decision 12, as everywhere in this package: these are facts about a
  document. A path a document does not declare is unknown, not wrong, and
  nothing here produces a finding, a severity or a verdict.
  """

  alias StatifierDatamodel.Index

  @doc """
  ADR-0001 decision 7's projection, taken straight off a decoded document.

  A map carrying a list under `"scopes"` is a document and projects to its
  declared-path set; **an empty document projects to `MapSet.new()`, not to
  `nil`**. That distinction is decision 6's and it is the whole reason this
  function has a `nil`: a host that supplied a document declaring nothing
  has made a claim about its data universe, while `nil` is reserved for an
  input that is not a document at all.

      iex> StatifierDatamodel.Document.declared_paths(%{"scopes" => []})
      MapSet.new([])

      iex> StatifierDatamodel.Document.declared_paths(%{"version" => 1, "scopes" => [
      ...>   %{"scope" => "local", "entries" => [
      ...>     %{"name" => "step", "path" => "signup.step", "type" => "string",
      ...>       "label" => "Step"}]}]})
      MapSet.new(["signup.step"])

      iex> StatifierDatamodel.Document.declared_paths(%{"scopes" => "not a list"})
      nil

      iex> StatifierDatamodel.Document.declared_paths(["signup.step"])
      nil
  """
  @spec declared_paths(term()) :: MapSet.t(String.t()) | nil
  def declared_paths(document) do
    case Index.index(document) do
      nil -> nil
      index -> Index.declared_paths(index)
    end
  end

  @doc """
  The declared paths strictly under `prefix`, in the document's own order -
  decision 7's completion query, reached through
  `StatifierDatamodel.Index.under/2` rather than restated here.

  This is the narrowing query an expression control needs and a shipped
  `<datalist>` does not: a datalist is handed the whole set once and the
  browser filters it, while a control that re-renders per keystroke wants
  only the branch the author is inside. Both read the same document,
  through the same one implementation of the projection.

  `prefix` itself is not among the results, matching `under/2`; an input
  that is not a document has no order to query and returns `[]`.

      iex> alias StatifierDatamodel.Document
      iex> Document.candidates_under(
      ...>   %{"scopes" => [%{"scope" => "local", "entries" => [
      ...>     %{"path" => "card", "type" => "object", "fields" => [
      ...>       %{"path" => "card.brand"}, %{"path" => "card.last4"}]}]}]},
      ...>   "card")
      ["card.brand", "card.last4"]

      iex> StatifierDatamodel.Document.candidates_under(["card.brand"], "card")
      []
  """
  @spec candidates_under(term(), term()) :: [String.t()]
  def candidates_under(document, prefix) do
    case Index.index(document) do
      nil -> []
      index -> index |> Index.under(prefix) |> Enum.map(& &1.path)
    end
  end

  @doc """
  The value enumerations the document declares, per path: every indexed
  entry whose `one_of` yields at least one drawable option.

  A declared value is offered when it can be drawn as an option - a string
  as itself, a number or a boolean as its printed form. Anything else, a
  list or an object or a `null`, is dropped, and **a path whose whole
  enumeration drops out is absent rather than present and empty**. That
  asymmetry is deliberate: `[]` is a host's spelling of *offer nothing
  here*, and a derivation must not be able to write it by accident.

  ## This does not promote the hint

  Nothing here validates and nothing refuses. `one_of` is a completion hint
  listing the values a host expects, and whether it is a hint or a claim is
  an open question on the record; defaulting a picker from it is a *use* of
  the hint rather than an answer to that question, and a value control fed
  from it still admits anything the author types. That is the same
  suggests-never-constrains posture the whole package takes.

  A consumer that also lets a host supply its own per-path map merges that
  map over this one, in its own package: what replaces what is that
  consumer's decision, and this function answers only for what the document
  declares.

      iex> alias StatifierDatamodel.Document
      iex> Document.declared_values(%{"scopes" => [%{"scope" => "local", "entries" => [
      ...>   %{"path" => "signup.step", "type" => "string",
      ...>     "one_of" => ["details", "payment", "review"]},
      ...>   %{"path" => "signup.email", "type" => "string"}]}]})
      %{"signup.step" => ["details", "payment", "review"]}

      iex> StatifierDatamodel.Document.declared_values(["signup.step"])
      %{}
  """
  @spec declared_values(term()) :: %{optional(String.t()) => [String.t()]}
  def declared_values(document) do
    case Index.index(document) do
      nil ->
        %{}

      index ->
        index
        |> Index.entries()
        |> Enum.reduce(%{}, &declared_value/2)
    end
  end

  @spec declared_value(Index.entry(), map()) :: map()
  defp declared_value(entry, acc) do
    case options(Map.get(entry, :one_of)) do
      [] -> acc
      values -> Map.put(acc, entry.path, values)
    end
  end

  @spec options(term()) :: [String.t()]
  defp options(one_of) when is_list(one_of), do: Enum.flat_map(one_of, &option/1)
  defp options(_absent), do: []

  @spec option(term()) :: [String.t()]
  defp option(value) when is_binary(value), do: [value]
  defp option(value) when is_boolean(value), do: [to_string(value)]
  defp option(value) when is_integer(value) or is_float(value), do: [to_string(value)]
  defp option(_undrawable), do: []
end
