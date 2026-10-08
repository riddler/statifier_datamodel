# StatifierDatamodel

[![CI](https://github.com/riddler/statifier_datamodel/actions/workflows/ci.yml/badge.svg)](https://github.com/riddler/statifier_datamodel/actions/workflows/ci.yml)
[![Hex.pm Version](https://img.shields.io/hexpm/v/statifier_datamodel.svg)](https://hex.pm/packages/statifier_datamodel)
[![Hex Downloads](https://img.shields.io/hexpm/dt/statifier_datamodel.svg)](https://hex.pm/packages/statifier_datamodel)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/statifier_datamodel/)
[![License](https://img.shields.io/hexpm/l/statifier_datamodel.svg)](https://github.com/riddler/statifier_datamodel/blob/main/LICENSE)

The shared type registry the family's documents, blocks and expressions agree
on. It reads a datamodel document - a host's typed description of the data an
author writes conditions against - and answers what the document alone can
settle: which paths it declares, what type each one holds, whether a value
read at a path satisfies the type a step expects, and whether a redefined type
still serves the readers of the one it replaces.

## Why this package

A host describes its data once, but more than one tool reads that
description: the block editor checks that a step reads what an earlier step
wrote, and the expression editor offers the paths a condition may name and the
values each may take. When each tool reads the document its own way, they
drift apart on what a path holds and on whether a read is satisfied, and an
author sees one answer in one place and another answer somewhere else. This
package is the one reader both take. Every function is pure and total, each
returns a fact rather than a verdict, and the package depends on nothing
else in the family, so either tool can take it without taking the other, and
both give the same answer about the same document.

## Install

Add `statifier_datamodel` to the dependencies in your `mix.exs`:

```elixir
def deps do
  [
    {:statifier_datamodel, "~> 0.5.0"}
  ]
end
```

## Basic usage

A library loan: a copy of a book lent to a patron, due on a date, renewed,
returned or lost. The host declares a `library.loan` record and a `Renewable`
shape a renewal step reads, and types the `loan` entry by the record. Index
the document, read the type the index holds at a path, and hand it to the read
check. An undeclared path answers `nil`, which the caller turns into
`:unknown`: unknown, not wrong.

```elixir
iex> alias StatifierDatamodel.{Declarations, Index, Types}
iex> document = %{
...>   "scopes" => [
...>     %{"scope" => "local", "label" => "Chart-local", "entries" => [
...>       %{"name" => "loan", "path" => "loan", "type" => "library.loan", "label" => "Loan"},
...>       %{"name" => "status", "path" => "status", "type" => "string", "label" => "Status",
...>         "one_of" => ["on_loan", "returned", "lost"]}]}],
...>   "types" => [
...>     %{"name" => "library.loan", "kind" => "record", "label" => "Loan", "fields" => [
...>       %{"name" => "patron_id", "type" => "string", "required?" => true},
...>       %{"name" => "due_on", "type" => "date", "required?" => true},
...>       %{"name" => "renewals", "type" => "integer"}]},
...>     %{"name" => "Renewable", "kind" => "shape", "label" => "Renewable", "fields" => [
...>       %{"name" => "due_on", "type" => "date", "required?" => true},
...>       %{"name" => "renewals", "type" => "integer", "required?" => true}]}]}
iex> index = Index.index(document)
iex> index.order
["loan", "loan.patron_id", "loan.due_on", "loan.renewals", "status"]
iex> Index.path_types(index)["status"]
{:one_of, ["on_loan", "returned", "lost"]}
iex> declarations = Declarations.from_document(document)
iex> held = Index.type(index, "loan") || :unknown
iex> Types.satisfies(declarations, held, {:declared, "Renewable"})
{:missing, ["renewals"]}
iex> Types.satisfies(declarations, Index.type(index, "loan.fine") || :unknown, :integer)
:unknown
```

The loan record leaves `renewals` optional, so it has not promised the value a
renewal step reads, and the read check names that field. Marking it required
in the record is the one-key fix.

## Documentation

- Learn
  - [Basic usage](#basic-usage): a loan document indexed, and a renewal step's read checked against it.
- Do
  - [Check a redefined type before you ship it](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.Compatibility.html): every way the new declaration narrows the old one, in the API reference until a guide page exists.
  - [Find the required fields a value leaves unfilled](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.Coverage.html): a map checked against a shape, in the API reference until a guide page exists.
  - [Validate a document before you index it](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.Schema.html): where the JSON Schema is and what it rejects, in the API reference until a guide page exists.
  - [Upgrade a host](docs/upgrading.md): what a host changes for each minor from 0.4 on.
- Look up
  - [The index](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.Index.html): admission, declared paths, the type at a path, and the value kinds an expression editor reads.
  - [The document shorthand](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.Document.html): declared paths, candidates under a prefix and declared values, straight from a document.
  - [Declarations](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.Declarations.html): the document's named records and shapes, indexed by name.
  - [Types and the read check](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.Types.html): the type expressions, inline shapes, and every answer `satisfies/3` gives.
  - [The changelog](https://github.com/riddler/statifier_datamodel/blob/main/CHANGELOG.md): what changed in each version.
- Understand
  - [Why the family shares one type registry](docs/explanation/why-one-type-registry.md): why the block editor and the expression editor read the document through one package that depends on neither, and what that costs.
  - [What is here and what is not](https://hexdocs.pm/statifier_datamodel/StatifierDatamodel.html): the questions this package answers, and why the environment walk, rendering and enforcement live elsewhere.
  - [The decision records](https://github.com/riddler/statifier_datamodel/tree/main/docs/adr): why the document and the read check are shaped the way they are.

## Compatibility

The package needs Elixir 1.18 or later (`elixir: "~> 1.18"` in `mix.exs`) and
has no runtime dependencies.

Until 1.0, the public surface may change between minor releases: a release may
rename modules, functions or error vocabulary with no compatibility shim.
Every such change is recorded in the
[changelog](https://github.com/riddler/statifier_datamodel/blob/main/CHANGELOG.md)
under a bold **Breaking** heading that says what to do about it, and pinning
to an exact minor, `~> X.Y.0`, is the recommended way to take the package
until then.

## License

MIT - see
[LICENSE](https://github.com/riddler/statifier_datamodel/blob/main/LICENSE).
