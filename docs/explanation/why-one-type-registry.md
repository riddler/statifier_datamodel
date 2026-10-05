# Why the family shares one type registry

A host describes its data once, in a datamodel document, but several tools
read that description and each needs an answer from it. This page is about
why those tools read the document through one package, why that package
depends on nothing else in the family, and what the arrangement costs.

## One description, several readers

Take a library that lends copies of books to patrons. Its host declares a
`library.loan` record, with a required `patron_id` and `due_on` and an
optional `renewals` count, and types the `loan` path by that record. A chart
that handles a loan reads `loan.due_on` to decide when a reminder fires and
`loan.renewals` to decide whether another renewal is allowed. Three tools
look at that same declaration while an author builds the chart:

- the block editor, which checks that the renewal step reads a value an
  earlier step or the host actually put at `loan.renewals`;
- the expression editor, which offers `loan.due_on` as a date, so a condition
  on it gets the relative-date comparisons rather than the numeric ones;
- a screen that shows the patron their loan, whose text slots name paths in
  the same document and want to know whether each one is filled.

Each of them asks a question the document alone can settle: which paths
exist, what type each holds, whether the value at a path satisfies what a
step expects, and whether a redefined `library.loan` still serves every
read that assumed the old one.

## What goes wrong when each tool reads it its own way

The questions look small enough that each tool could answer them for itself.
The trouble is that the answers have edges, and two readers rarely draw the
edges in the same place. Is `renewals` present for a read when the record
marks it optional? Does a path declared as a bare `object` satisfy a read
that expects the `library.loan` record? Is a path the document never
mentions wrong, or only unknown? If the block editor says the renewal step's
read is satisfied and the expression editor greys out the same path, the
author sees two answers about one document and has no way to tell which tool
is right.

A shared reader removes that class of disagreement rather than each instance
of it. The index, the read check in `StatifierDatamodel.Types.satisfies/3`,
compatibility and coverage are written once, so every tool that takes them
draws the edges in the same place. In the loan above, the read check answers
that the loan record has not promised `renewals` to a step that requires it,
and every tool reports that same fact.

## Why the registry depends on nothing

The block editor already takes the expression editor's package as an
optional dependency, to embed it. If the document's reader lived in the block
editor's package, the expression editor would have to take that package back
to learn a path's value kind, and the two would form a cycle. If it lived in
the expression editor's package, every host that only compiles blocks would
carry an editor it never renders.

The document itself needs neither of them: it does not mention blocks, a
compiler or anything that renders. So the reader sits in a third package that
depends on nothing in the family, and each tool takes it without taking the
other. That is also why the package stops where it does. The walk over a
block document, which needs the block tree, stays with the blocks; anything
that draws a path or an operator stays with the editor; and nothing here
enforces a type while an execution is under way. A question that needs one of
those things is a sign that it belongs in the package that has it.

## Facts, not verdicts

Every function in the registry is pure and total over an admitted document,
and each returns a fact: a set of paths, a type, `true`, a list of missing
field names, `:unknown`. None returns a severity, a message or a finding.

The reason is that the same fact means different things to different
readers. A loan screen can show `loan.renewals` as blank when it is missing;
the block editor may treat the same gap as worth a warning before the chart
is published; a host may decide either is fine. If the registry said
"error", one of those readers would be wrong to obey it. Keeping the
judgement with the reader is what lets every reader share the fact.

## The alternatives

Several other arrangements were weighed, and each still has something going
for it.

**Keep the reader in the block editor's package and hand the expression
editor a plain map.** This was the quickest path, and for a while the map was
enough. It fails as a resting place because the map's derivation would live
in a package that optionally depends on the one consuming it. The next thing
the expression editor wanted from the document, labels or the hinted values
for a field, would either widen the map one key at a time or close the cycle.

**Let each tool keep its own reader.** It costs nothing up front, and each
tool can shape the answers to its own needs. It is exactly the arrangement
the section above describes going wrong: the readers agree on the easy cases
and drift on the edges, and nothing catches the drift except an author who
notices two answers.

**Describe the types in a second artifact beside the document.** A separate
file of record and shape declarations would keep the document as it was. It
would also mean a second input that a tool may or may not have been handed,
and declarations whose fields name paths with no document to check those
paths against. Declaring the types inside the document keeps one artifact and
one delivery.

**A separate registry for what a screen's text reads.** A screen's slots read
the same paths a chart reads, so a second registry would be a second list of
the same names, kept in step by hand. Typing the screen's paths from the same
document lets a loan record declared once type both the chart's reads and
the screen's. What a template does to a value on the way to the screen, such
as formatting a due date, is a transformation rather than a type, and it
stays with the package that renders the screen.

## What it costs

A shared reader is slower to change. A new answer, such as a new scalar type
or a different reading of an optional field, is a change every tool takes at
once, and so it is decided in this package and recorded, rather than
patched into whichever tool noticed the need first. That is the point of
sharing it, but it means a tool that wants a different edge cannot simply
draw one.

Record identity is nominal, and the cost of that falls on hosts. Two records
with the same fields do not satisfy each other: a `library.loan` and an
`interlibrary.loan` with identical fields are still two types. A host that
wants one step to read both declares a shape that both cover, such as a
`Renewable` shape requiring `due_on` and `renewals`, and the step reads the
shape. Structural identity was refused rather than postponed, because whether
one record may stand in for another has a different answer in every host, and
the host relation that the block editor's palette carries is where a host
gives that answer.

The type set is closed. A value the document cannot type is declared as a
bare `object` or left undeclared, and every reader treats it as unknown
rather than guessing. A closed set keeps every rendering table finite, and
the next real type is added here, once, for every reader.

## Where to go next

The module pages hold the details this page leaves out: `StatifierDatamodel.Index`
for the paths and their types, `StatifierDatamodel.Types` for the read check
and every answer it gives, `StatifierDatamodel.Compatibility` for what a
redefined declaration may change, and `StatifierDatamodel.Coverage` for the
fields a value leaves unfilled. The reasoning behind the document's shape is
in [the decision records](https://github.com/riddler/statifier_datamodel/tree/main/docs/adr).
