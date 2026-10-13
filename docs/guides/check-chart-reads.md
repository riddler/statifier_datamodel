# Check the paths a chart's conditions read

This guide shows you how to check every path a chart's conditions read
against your datamodel document: the `_event.data` paths against the payload
type each event declares, and every other path against the declared paths.
The expression language lists the reads; `StatifierDatamodel.Reads.undeclared/2`
checks them.

`statifier_datamodel` never parses an expression and does not depend on the
expression language. Your host does both halves: it asks predicator for each
condition's reads, then hands them to this package as data.

## Before you start

You need:

- a datamodel document whose `events` key declares the events your chart
  receives and the type of each payload (see `StatifierDatamodel.Events`);
- predicator 9.5.0 or later in your host's own dependencies, for
  `Predicator.Analysis.references/1`:

  ```elixir
  {:predicator, "~> 9.5"}
  ```

- each condition you want checked, as its source string, with the event
  names its transition is taken on (the transition's `event` attribute) and
  something that lets you find it again, such as the state and the
  transition's position in it.

The examples below use this document, a library loan. It declares two
chart-local paths, two records, and the two events a loan chart receives:

```elixir
document = %{
  "version" => 1,
  "scopes" => [
    %{"scope" => "local", "label" => "Chart-local", "entries" => [
      %{"name" => "copy_id", "path" => "loan.copy_id", "type" => "string", "label" => "Copy"},
      %{"name" => "due_on", "path" => "loan.due_on", "type" => "date", "label" => "Due on"}]}],
  "types" => [
    %{"name" => "loans.renewal", "kind" => "record", "label" => "Renewal", "fields" => [
      %{"name" => "copy_id", "type" => "string", "required?" => true},
      %{"name" => "due_on", "type" => "date", "required?" => true},
      %{"name" => "renewals", "type" => "integer", "required?" => true}]},
    %{"name" => "loans.return", "kind" => "record", "label" => "Return", "fields" => [
      %{"name" => "copy_id", "type" => "string", "required?" => true},
      %{"name" => "returned_at", "type" => "datetime", "required?" => true}]}],
  "events" => [
    %{"name" => "loan.renewed", "type" => "loans.renewal", "label" => "Loan renewed"},
    %{"name" => "loan.returned", "type" => "loans.return", "label" => "Copy returned"}]
}
```

## 1. List each condition's reads

Call `Predicator.Analysis.references/1` on each condition. It answers every
variable the condition reads, in source order, each as a path of segments:
a string for a name, an integer for a literal index, `:dynamic` for a
computed key.

Turn each reference into a read this package takes by adding two keys:
`events`, the event names the condition is read under, and `location`,
anything you want back with the answer. A transition's `event` attribute is
a space-separated list of descriptors, so split it; a transition with no
event gives `[]`.

```elixir
defmodule MyHost.ChartReads do
  @moduledoc "Lists a chart's condition reads and checks them against a datamodel document."

  alias StatifierDatamodel.Reads

  # `conditions` is a list of `%{cond: source, event: attribute_or_nil, at: anything}`.
  def check(document, conditions) do
    with {:ok, reads} <- reads(conditions) do
      {:ok, Reads.undeclared(document, reads)}
    end
  end

  defp reads(conditions) do
    Enum.reduce_while(conditions, {:ok, []}, fn condition, {:ok, acc} ->
      case Predicator.Analysis.references(condition.cond) do
        {:ok, references} ->
          events = String.split(condition.event || "")

          reads =
            for %{path: path, position: position} <- references do
              %{events: events, path: path, location: {condition.at, position}}
            end

          {:cont, {:ok, acc ++ reads}}

        {:error, error} ->
          {:halt, {:error, {condition.at, error}}}
      end
    end)
  end
end
```

A condition that does not parse stops the check here with its error, which
is the expression language's to report; the datamodel document has nothing
to say about it.

## 2. Check the reads

Hand the document and the conditions in, and read the answer:

```elixir
MyHost.ChartReads.check(document, [
  %{cond: "_event.data.due_on > loan.due_on", event: "loan.renewed", at: {"on_loan", 0}},
  %{cond: "_event.data.fine_cents > 0", event: "loan.returned", at: {"on_loan", 1}},
  %{cond: "_event.data.copy_id == loan.copy_id", event: "loan", at: {"on_loan", 2}},
  %{cond: "_event.data.due_on != null", event: "loan.*", at: {"on_loan", 3}}
])
#=> {:ok,
#=>  [
#=>    {%{events: ["loan.returned"], path: ["_event", "data", "fine_cents"],
#=>       location: {{"on_loan", 1}, {1, 1}}},
#=>     {:undeclared, "loan.returned", ["_event", "data", "fine_cents"]}},
#=>    {%{events: ["loan.*"], path: ["_event", "data", "due_on"],
#=>       location: {{"on_loan", 3}, {1, 1}}},
#=>     {:undeclared, "loan.returned", ["_event", "data", "due_on"]}}
#=>  ]}
```

Every read the document declares is left out, so an empty list means every
path checked out. Each reported read comes back exactly as you handed it in,
with its location, and a reason:

- `{:undeclared, event_name, prefix}`: the payload type of `event_name` does
  not declare the path, and `prefix` is the path up to the first segment it
  does not declare. A condition on `loan` or `loan.*` is read under every
  event those names match, so it is reported once for each event whose
  payload lacks the path: above, `loan.returned`'s payload has no `due_on`.
- `:no_declared_event`: the condition reads `_event.data` but its event
  names match no event the document declares.
- `{:undeclared_path, prefix}`: a path outside `_event` that the
  document's declared paths do not hold, `prefix` being its leading name
  segments.

A read of `_event.name` and the other SCXML system fields is never
reported, and a computed key such as `_event.data.holds[i]` ends what is
checked at the bracket.

## 3. Leave out the reads you do not want checked

Once your document declares one path, every root other than `_event` is
checked against the declared paths. A condition that reads one of the SCXML
system variables, `_sessionid` for example, is then reported, because no
document declares it. If your host supplies those values itself, drop their
reads before the check:

```elixir
host_supplied = ~w(_sessionid _name _ioprocessors _x)

reads = Enum.reject(reads, fn %{path: [root | _]} -> root in host_supplied end)
```

The same filter is where to drop any other root your host supplies outside
the datamodel document.

## What to do with the answer

The answer is a list of facts. Nothing in it refuses your chart: whether a
reported read stops a save, warns an author, or is only logged is yours to
decide. To check a payload value rather than a path, against the type its
event declares, see `StatifierDatamodel.Conformance.conforms/3`.
