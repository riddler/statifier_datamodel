# StatifierDatamodel

[![CI](https://github.com/riddler/statifier_datamodel/actions/workflows/ci.yml/badge.svg)](https://github.com/riddler/statifier_datamodel/actions/workflows/ci.yml)
[![Hex.pm Version](https://img.shields.io/hexpm/v/statifier_datamodel.svg)](https://hex.pm/packages/statifier_datamodel)
[![Hex Downloads](https://img.shields.io/hexpm/dt/statifier_datamodel.svg)](https://hex.pm/packages/statifier_datamodel)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/statifier_datamodel/)
[![License](https://img.shields.io/hexpm/l/statifier_datamodel.svg)](https://github.com/riddler/statifier_datamodel/blob/main/LICENSE)

The datamodel document and what can be decided from it, with no dependency on
the block editor, the compiler, or the UI.

A datamodel document is a host's typed description of the data universe an
author writes conditions against. It has three scopes - `global`, `local`,
`event` - each carrying entries with a `name`, an absolute dotted `path`, a
`type` and a `label`; and a `types` key of named record and shape
declarations, each with ordered `fields` carrying `name`, `type` and
`required?`. This package is the reader of that document, and the home of
every question that can be answered from the document alone.

The contract is
[ADR-0001](https://github.com/riddler/statifier_datamodel/blob/main/docs/adr/0001-datamodel-document.md);
the document shape and the index are re-homed here from statifier_blocks'
ADR-0006, and ADR-0001 is the record of the re-homing.

## Installation

```elixir
def deps do
  [
    {:statifier_datamodel, "~> 0.4"}
  ]
end
```

## What it answers

Every example below is a doctest: `test/readme_test.exs` runs this file, so a
snippet that stops being true fails the suite. The worked domain is
credit-card processing, as it is everywhere in this family.

### The index

`StatifierDatamodel.Index.index/1` admits a decoded document and returns the
path/type index over it. Every entry contributes its own path at every
nesting depth, in document order, and nothing else does. Admission is a total
normalizer: a map carrying a list under `"scopes"` is a document, and
anything else is `nil` - so *not a document* stays distinguishable from *a
document declaring nothing*.

    iex> alias StatifierDatamodel.Index
    iex> document = %{
    ...>   "version" => 1,
    ...>   "scopes" => [
    ...>     %{"scope" => "local", "label" => "Chart-local", "entries" => [
    ...>       %{"name" => "amount_cents", "path" => "amount_cents",
    ...>         "type" => "integer", "label" => "Amount (minor units)"},
    ...>       %{"name" => "card", "path" => "card", "type" => "object",
    ...>         "label" => "Card", "fields" => [
    ...>           %{"name" => "brand", "path" => "card.brand", "type" => "string",
    ...>             "label" => "Brand",
    ...>             "one_of" => ["visa", "mastercard", "amex"]},
    ...>           %{"name" => "expires_on", "path" => "card.expires_on",
    ...>             "type" => "date", "label" => "Expires on"}]}]}]}
    iex> index = Index.index(document)
    iex> index.order
    ["amount_cents", "card", "card.brand", "card.expires_on"]
    iex> Index.type(index, "card.expires_on")
    :date
    iex> Index.declared?(index, "card.cvv")
    false
    iex> Index.index(["amount_cents"])
    nil

### The declared paths

`StatifierDatamodel.Document` is the shorthand for a consumer that holds a
document rather than an index: it admits its argument through the index and
answers totally either way. `declared_paths/1` is the projection an editor's
undeclared-path advisory reads; an empty document projects to an empty set,
and only a non-document is `nil`.

    iex> alias StatifierDatamodel.Document
    iex> document = %{"scopes" => [%{"scope" => "local", "entries" => [
    ...>   %{"name" => "card", "path" => "card", "type" => "object", "fields" => [
    ...>     %{"name" => "last4", "path" => "card.last4", "type" => "string"},
    ...>     %{"name" => "brand", "path" => "card.brand", "type" => "string",
    ...>       "one_of" => ["visa", "mastercard", "amex"]}]}]}]}
    iex> Document.declared_paths(document)
    MapSet.new(["card", "card.brand", "card.last4"])
    iex> Document.candidates_under(document, "card")
    ["card.last4", "card.brand"]
    iex> Document.declared_values(document)
    %{"card.brand" => ["visa", "mastercard", "amex"]}
    iex> Document.declared_paths(%{"scopes" => []})
    MapSet.new([])
    iex> Document.declared_paths(["card"])
    nil

### The declared types and the read check

A **record** is a fact about what a write puts at a path; a **shape** is a
constraint a read places on one. `StatifierDatamodel.Declarations` indexes
the document's `types` key to `name -> declaration`, and
`StatifierDatamodel.Types` decides the read check over it: unknown is
permissive both ways, then identity, then a record read as a shape is
admitted when the record's fields cover the shape's required set. Covering a
required shape field takes a record field of the same name that the record
also declares required: an optional field has not promised the value, so it
does not cover. Identity is nominal - there is no structural widening between
two records. `satisfies/3` returns the reason a consumer renders;
`satisfies?/3` is the same check as a boolean.

    iex> alias StatifierDatamodel.{Declarations, Types}
    iex> declarations = Declarations.from_document(%{"types" => [
    ...>   %{"name" => "cards.credit_txn", "kind" => "record",
    ...>     "label" => "Credit transaction", "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "currency", "type" => "string", "required?" => true},
    ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => true}]},
    ...>   %{"name" => "Settleable", "kind" => "shape", "label" => "Settleable",
    ...>     "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "currency", "type" => "string", "required?" => true},
    ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => true}]},
    ...>   %{"name" => "Refundable", "kind" => "shape", "label" => "Refundable",
    ...>     "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "settled_at", "type" => "datetime", "required?" => true}]}]})
    iex> Types.satisfies(declarations, {:declared, "cards.credit_txn"}, {:declared, "Settleable"})
    :covers
    iex> Types.satisfies(declarations, {:declared, "cards.credit_txn"}, {:declared, "Refundable"})
    {:missing, ["settled_at"]}
    iex> Types.satisfies?(declarations, {:declared, "cards.credit_txn"}, {:declared, "Refundable"})
    false
    iex> Types.satisfies(declarations, :date, :date)
    :identical

Drop the `required?` on the record's `authorized_at` and the same read stops
being satisfied, naming that field the way an absent one is named. The fix in
the document is one key: mark the field required where the record does
promise the value.

    iex> alias StatifierDatamodel.{Declarations, Types}
    iex> loose = Declarations.from_document(%{"types" => [
    ...>   %{"name" => "cards.credit_txn", "kind" => "record",
    ...>     "label" => "Credit transaction", "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "currency", "type" => "string", "required?" => true},
    ...>       %{"name" => "authorized_at", "type" => "datetime"}]},
    ...>   %{"name" => "Settleable", "kind" => "shape", "label" => "Settleable",
    ...>     "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "currency", "type" => "string", "required?" => true},
    ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => true}]}]})
    iex> Types.satisfies(loose, {:declared, "cards.credit_txn"}, {:declared, "Settleable"})
    {:missing, ["authorized_at"]}

### An inline, unnamed shape

A consumer holding a value the host never declared - a fan-out's collected
envelope, a block's computed summary - says what it holds with
`{:shape, members}`, where each member carries `name`, `type` and
`required?`. It is read the same way a declaration is: a record covers it
member-wise, it covers a declared shape, and two inline shapes compare
structurally. It never satisfies a declared **record**, whose identity is
nominal, and a declared shape held covers nothing but itself. Identity for
the arm is member-set-wise, so member order is a rendering decision and not
a difference. There is no document spelling for one: `parse/2` reads only
strings, and an inline shape enters as an argument to the read check.

    iex> alias StatifierDatamodel.{Declarations, Types}
    iex> declarations = Declarations.from_document(%{"types" => [
    ...>   %{"name" => "ChunkSummary", "kind" => "shape", "label" => "Chunk summary",
    ...>     "fields" => [
    ...>       %{"name" => "authorized_count", "type" => "integer", "required?" => true},
    ...>       %{"name" => "declined_count", "type" => "integer", "required?" => true}]}]})
    iex> summary = {:shape, [
    ...>   %{name: "authorized_count", type: :integer, required?: true},
    ...>   %{name: "declined_count", type: :integer, required?: true}]}
    iex> envelope = {:shape, [
    ...>   %{name: "index", type: :integer, required?: true},
    ...>   %{name: "status", type: :string, required?: true},
    ...>   %{name: "donedata", type: summary, required?: false}]}
    iex> Types.satisfies(declarations, summary, {:declared, "ChunkSummary"})
    :covers
    iex> Types.satisfies(declarations, envelope, {:declared, "ChunkSummary"})
    {:missing, ["authorized_count", "declined_count"]}
    iex> Types.to_string(summary)
    "{authorized_count: integer, declined_count: integer}"

The envelope's own members are `index`, `status` and `donedata`: the summary
is one member down, and this package widens nothing to find it.

### An entry typed by a declaration

An entry's `type`, and a `list` entry's `item_type`, may name a declaration
instead of one of the nine types. The reference is nominal - the index
carries `{:declared, name}`, not a copy of the fields - and the entry then
contributes the declaration's fields beneath its own path, exactly as an
inlined `object` entry contributes its `fields`. A name the `types` key does
not declare stays unknown, as it always has.

    iex> alias StatifierDatamodel.Index
    iex> index = Index.index(%{"scopes" => [
    ...>   %{"scope" => "local", "entries" => [
    ...>     %{"name" => "txn", "path" => "txn", "type" => "cards.credit_txn",
    ...>       "label" => "Transaction"},
    ...>     %{"name" => "note", "path" => "note", "type" => "cards.nothing"}]}],
    ...>   "types" => [
    ...>     %{"name" => "cards.credit_txn", "kind" => "record",
    ...>       "label" => "Credit transaction", "fields" => [
    ...>         %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>         %{"name" => "card", "type" => "cards.card", "required?" => true}]},
    ...>     %{"name" => "cards.card", "kind" => "record", "label" => "Card",
    ...>       "fields" => [
    ...>         %{"name" => "brand", "type" => "string",
    ...>           "one_of" => ["visa", "mastercard", "amex"]}]}]})
    iex> index.order
    ["txn", "txn.amount_cents", "txn.card", "txn.card.brand", "note"]
    iex> Index.type(index, "txn.card")
    {:declared, "cards.card"}
    iex> Index.type(index, "note")
    nil
    iex> Index.path_types(index)
    %{
      "txn.amount_cents" => :number,
      "txn.card.brand" => {:one_of, ["visa", "mastercard", "amex"]}
    }

`txn` and `txn.card` are absent from the value kinds for the same reason an
`object` entry is: neither is a value the expression language has a kind
for. A cycle between declarations discharges rather than recurring, so
`index/1` stays total over any document a host can write.

### Compatibility of a redefined declaration

`StatifierDatamodel.Compatibility.breaks/2` is given the declaration a name
had and the declaration replacing it, and lists every way the new one narrows
the old one - every reason a read that held under the old might not hold
under the new - ordered by field name. The list is empty when the
redefinition takes nothing away; a name declared on neither side is `:error`,
never an empty list.

    iex> alias StatifierDatamodel.{Compatibility, Declarations}
    iex> was = Declarations.from_document(%{"types" => [
    ...>   %{"name" => "cards.credit_txn", "kind" => "record",
    ...>     "label" => "Credit transaction", "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "currency", "type" => "string", "required?" => true},
    ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => true}]}]})
    iex> now = Declarations.from_document(%{"types" => [
    ...>   %{"name" => "cards.credit_txn", "kind" => "record",
    ...>     "label" => "Credit transaction", "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "currency", "type" => "string", "required?" => false}]}]})
    iex> {:ok, old} = Declarations.fetch(was, "cards.credit_txn")
    iex> {:ok, new} = Declarations.fetch(now, "cards.credit_txn")
    iex> Compatibility.breaks(old, new)
    [{:field_removed, "authorized_at"}, {:made_optional, "currency"}]
    iex> Compatibility.breaks(old, old)
    []
    iex> Compatibility.breaks(nil, nil)
    :error

Each break names its kind first and the field second. The kind is the row of
the record's table the break came from - `:field_removed`, `:type_changed`,
`:made_required`, `:required_added` or `:made_optional`, one per breaking row
and no others - so a host words a warning by matching on it rather than by
comparing the two declarations again.

Both changes break: dropping `authorized_at` takes the field away, and
relaxing `currency` takes away the promise that the value is there, which
the read check has read as *not covered* since decision 8 was amended. What
does not break is a widening - an optional field added - and a `one_of`,
which is a completion hint and not a constraint however it is edited.

    iex> alias StatifierDatamodel.{Compatibility, Declarations}
    iex> hinted = fn one_of -> Declarations.from_document(%{"types" => [
    ...>   %{"name" => "cards.card", "kind" => "record", "label" => "Card",
    ...>     "fields" => [
    ...>       %{"name" => "brand", "type" => "string", "required?" => true,
    ...>         "one_of" => one_of}]}]}) end
    iex> {:ok, old} = Declarations.fetch(hinted.(["visa", "mastercard", "amex"]), "cards.card")
    iex> {:ok, new} = Declarations.fetch(hinted.(["visa"]), "cards.card")
    iex> Compatibility.breaks(old, new)
    []

This answers *may a reader keep reading*, not *did anything change*.

### Coverage of a map against a shape

`StatifierDatamodel.Coverage.missing/3` returns the `name` of every required
field of a shape that a map does not fill, in declaration order. "Fill" is
presence of the key with a non-`nil` value; the value's type is the
expression language's question, not this one's. A name that is not declared,
or that is a record rather than a shape, is `:error`.

    iex> alias StatifierDatamodel.{Coverage, Declarations}
    iex> declarations = Declarations.from_document(%{"types" => [
    ...>   %{"name" => "Settleable", "kind" => "shape", "label" => "Settleable",
    ...>     "fields" => [
    ...>       %{"name" => "amount_cents", "type" => "integer", "required?" => true},
    ...>       %{"name" => "currency", "type" => "string", "required?" => true},
    ...>       %{"name" => "authorized_at", "type" => "datetime", "required?" => true}]},
    ...>   %{"name" => "cards.card", "kind" => "record", "label" => "Card",
    ...>     "fields" => [
    ...>       %{"name" => "last4", "type" => "string", "required?" => true}]}]})
    iex> Coverage.missing(declarations, "Settleable", %{"amount_cents" => 4200, "currency" => "USD"})
    {:ok, ["authorized_at"]}
    iex> Coverage.missing(declarations, "Settleable", %{"currency" => nil})
    {:ok, ["amount_cents", "currency", "authorized_at"]}
    iex> Coverage.missing(declarations, "cards.card", %{})
    :error

### Value kinds for an expression editor

`StatifierDatamodel.Index.path_types/1` projects the index to
`%{path => kind | {:list, kind} | {:one_of, values}}`, in the expression
language's own vocabulary: `integer` and `decimal` are both `:number`, a
`list` with a scalar `item_type` is `{:list, kind}`, and a drawable `one_of`
wins over the kind. An `object`, a `list` with no usable `item_type` and an
unknown type are **absent** from the map - absence means unknown, not wrong,
and an editor handed the map treats a path it does not contain exactly as it
treats every path today.

    iex> alias StatifierDatamodel.Index
    iex> %{"scopes" => [%{"scope" => "local", "entries" => [
    ...>   %{"path" => "amount_cents", "type" => "integer"},
    ...>   %{"path" => "risk_reasons", "type" => "list", "item_type" => "string"},
    ...>   %{"path" => "card", "type" => "object", "fields" => [
    ...>     %{"path" => "card.brand", "type" => "string",
    ...>       "one_of" => ["visa", "mastercard", "amex"]},
    ...>     %{"path" => "card.expires_on", "type" => "date"}]}]}]}
    ...> |> Index.index()
    ...> |> Index.path_types()
    %{
      "amount_cents" => :number,
      "risk_reasons" => {:list, :string},
      "card.brand" => {:one_of, ["visa", "mastercard", "amex"]},
      "card.expires_on" => :date
    }

## What is not here

Every function is pure and total over an admitted document, and returns a
fact - a set, an index, a boolean, a list of names, a map. Nothing here
produces a finding, a severity or a verdict: an undeclared path is unknown,
not wrong, and an unsatisfied read is something a consumer assigns a severity
to in its own record.

What is deliberately elsewhere: the environment walk over a block document,
which needs the block tree and stays in
[statifier_blocks](https://github.com/riddler/statifier_blocks); anything
that renders, which is
[statifier_ui](https://github.com/riddler/statifier-ui)'s; and any runtime
enforcement, which no record in the family has asked for.

## Who takes this

statifier_blocks reads the document through this package today, for the typed
environment's read check. statifier_ui takes `path_types/1`'s map as the
expression editor's assign in a later release. Neither takes the other for
the document, and this package depends on nothing in the family - that
property is the whole reason it exists, and a runtime dependency added here
is a decision to record.

## License

MIT - see
[LICENSE](https://github.com/riddler/statifier_datamodel/blob/main/LICENSE).
