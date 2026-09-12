# Spike: statifier_datamodel as the shared type registry for element contexts

**Status: findings, 2026-09-12 (campaign SF040, bead `sd-2mq`). Capture-only:
this document is the deliverable; nothing in `lib/` changed and no dependency
was added.** Read at `9bc5041`.

The campaign plan files this spike under Riddler's element-type-registry
question; the question it actually answers is the neighbouring open one -
what this package declares for a path's collected answer set - and the asks
in section 6 are written against that. Both are recorded here so whoever
reads the findings against the plan is not surprised.

The question behind the spike is whether one datamodel document can type both
what a chart reads and what a screen's text slot reads, so that a host does not
end up maintaining two registries of the same names. The spike expresses a
three-screen signup path's context as a datamodel document, prototypes a
`paths_read/1` over a Liquid template's parsed form, and feeds the paths it
finds to this package's index, read check and coverage.

## What was built, and where

| Piece | Where it lives |
|---|---|
| The context document | Appendix A below, and `priv/signup_screens.datamodel.json` in the scratch project |
| `paths_read/1` over `solid`'s parsed template | Appendix B below |
| The run that feeds the paths to `Index`, `Types` and `Coverage` | Appendix C below |

The scratch project is a throwaway `mix` project **outside this repository**
(`sd-2mq-solid-scratch/` in the campaign session's scratchpad), with
`{:solid, "~> 1.0"}` - resolved to `solid 1.3.3` - and this package as a path
dependency. `solid` is **not** added to `statifier_datamodel`: this package's
`deps/0` says a runtime dependency here is a decision to record, and no record
has taken one.

The k1 element-document fixture was being authored in parallel in
`statifier_examples` while this spike ran, so the context below was derived
from the campaign plan's four element types (heading, text, text_question,
button-with-outcome) and the signup vocabulary the examples repository already
uses. **The real fixture may differ**; where it does, the shape of the findings
survives but the field names do not.

## 1. The element context as a datamodel document

Answers are keyed by element key and flat (`answers.<element_key>`), so the
whole answer set is one entry in the `local` scope, declared **as a record**
rather than as a bare `object`:

```json
{"name": "answers", "path": "answers", "type": "signup.answers", "label": "Answers"}
```

Three things follow from declaring it as a record rather than as an object with
inline `fields`:

- the index flattens the record's fields into paths anyway
  (`answers.first_name`, `answers.email`, ...; see the path list in
  Appendix C, section 5), so a completion pane loses nothing;
- the same declaration types the **event** entry the screen's submit carries
  (`event.answers`), which is what `core.on_event`'s `capture` map writes into
  the local scope. One declaration, two scopes, no duplication;
- a text slot's read of the whole answer set can be checked against a *shape*,
  which is the part an `object` cannot do.

The document's `global` scope carries the request roots the host knows before
any screen is answered (`request.locale`, `request.started_at`,
`request.utm_source`). They are not written by a screen, and nothing in the
document says so - see ask 4.

`types` declares two records (`signup.answers`, `signup.invite`) and two shapes
(`Greetable`, `Contactable`) - what a greeting slot needs, and what a
confirmation slot needs. The full document is Appendix A.

## 2. `paths_read/1` over solid's parsed template

`Solid.parse/1` returns a `Solid.Template` whose `parsed_template` is a list of
structs, and every variable read in it - in an output, in an `{% if %}`
condition, in a `{% for %}` enumerable, in a filter argument - is a
`Solid.Variable` carrying `identifier`, `accesses` and a convenience
`original_name`. A generic structural walk collects them; three things make the
walk more than a `Macro.prewalk`:

- **`original_name` is not a path.** It is the source spelling, so
  `answers["first_name"]` and `answers.first_name` arrive as different strings
  for the same path, and `answers[key]` arrives as a string naming a path no
  document can declare. The prototype builds the path from `accesses` instead:
  an `AccessLiteral` with a binary value is a segment whichever way it was
  spelled; an `AccessLiteral` with an integer value is a list index, which the
  document types by `item_type` rather than by a path of its own; an
  `AccessVariable` makes the read **dynamic** and everything past it
  unknowable. A dynamic read is reported at the longest static prefix, with a
  flag.
- **Templates bind their own names.** `{% for invite in answers.invites %}`
  binds `invite` for its body, and `{% assign %}` / `{% capture %}` bind their
  target for everything after them. Without that, the walk reports
  `invite.email` and `greeting` as datamodel paths, which are not paths at all.
  The prototype threads a binding set left to right through each node list and
  subtracts it. This was an actual defect in the first cut of the prototype,
  caught by the run.
- **The filter chain belongs to the read.** A filter is attached to the
  enclosing `Solid.Object`, not to the variable, so the walk carries the chain
  down to the variable it wraps.

Over the slot in Appendix C, the prototype reports:

```
  answers                    dynamic?=true optional?=false filters=[] line=7
  answers.company_name       dynamic?=false optional?=true filters=["default"] line=2
  answers.email              dynamic?=false optional?=false filters=["downcase"] line=1
  answers.first_name         dynamic?=false optional?=false filters=["capitalize"] line=1
  answers.invites            dynamic?=false optional?=false filters=[] line=5
  answers.plan               dynamic?=false optional?=false filters=[] line=2
  answers.team_size          dynamic?=false optional?=false filters=[] line=3
  request.locale             dynamic?=false optional?=false filters=[] line=3
  request.started_at         dynamic?=false optional?=false filters=["date"] line=3
```

One known limitation of the prototype, stated rather than fixed: it merges the
filter chains of two reads of the same path into one entry, so
`answers.first_name` above shows `capitalize` although one of its two reads is
unfiltered. A production version keys reads by occurrence, not by path.

## 3. What the index, the read check and coverage answer today

The surfaces the spike calls, named exactly, because "the read check" is a
concept here and not a function: there is **no** `read_check/_` in this
package. The read check IS `StatifierDatamodel.Types.satisfies/3`
(`lib/statifier_datamodel/types.ex:371` at `9bc5041`, anchor
`def satisfies(declarations, held, expected)`; `satisfies?/3` is the boolean
form at `:283`), with `types.ex`'s "## The read check" section as its
contract. `StatifierDatamodel.Coverage` exposes `missing/3` and nothing else
(`coverage.ex:54`). From `StatifierDatamodel.Index` the spike calls `index/1`,
`type/2`, `declared?/2`, `fetch/2` and reads `.order`; from
`StatifierDatamodel.Declarations`, `from_document/1`.

Every static path the slot reads resolves in the index, and the types the index
returns are already in the read check's grammar:
`t:StatifierDatamodel.Index.entry_type/0` (`index.ex`, the `entry_type` typedoc)
is `type() | {:declared, name}`, which is a subset of
`t:StatifierDatamodel.Types.t/0` (`types.ex`, the `t` typedoc). **No adapter is
needed between the index and the read check** - `Index.type/2`'s answer is
directly `satisfies/3`'s `held`. That is the single most useful finding
here: the registry seam already composes, with no code in this package to
write for it.

```
  answers                    declared?=true type={:declared, "signup.answers"} item_type=nil
  answers.invites            declared?=true type=:list item_type={:declared, "signup.invite"}
  answers.team_size          declared?=true type=:integer item_type=nil
  request.started_at         declared?=true type=:datetime item_type=nil
```

The read check over those held types, with the expectation a slot imposes:

```
  answers read as Greetable                                      signup.answers -> Greetable              :covers
  answers read as Contactable                                    signup.answers -> Contactable            {:missing, ["company_name"]}
  answers.first_name into a string slot                          string -> string                         :identical
  answers.team_size into a string slot (Liquid stringifies)      integer -> string                        :not_assignable
  answers.team_size into `plus`                                  integer -> integer                       :identical
  request.started_at into `date:`                                datetime -> datetime                     :identical
  answers.plan into an unconstrained slot                        string -> unknown                        :unknown
  the invite record into the loop body's inline expectation      signup.invite -> {email: string}         :covers
  an inline invite read where the record is expected             {email: string} -> signup.invite         :not_assignable
  an undeclared path's type (nil) read as a string               unknown -> string                        :unknown
```

Three of those lines carry the whole finding:

- a record read where a shape is expected **covers** it, field-wise, which is
  exactly what a slot's "I need a first name" expectation wants;
- the loop body's inline expectation over a list's `item_type` works in the
  direction a template needs (the declared record covers the inline shape), and
  refuses in the other, which is the nominal rule ADR-0001 decision 8 states
  and not a gap;
- `integer -> string` is `:not_assignable`. Liquid stringifies everything at
  output, so **every** non-string scalar read into a text slot would be refused
  if a text slot's expectation were spelled `:string`. See ask 1.

## 4. What this package needs to type a Liquid variable path

### Filters change the kind, and nothing here expresses that

A read is not `path : type`; it is `path : type` put through a chain. `downcase`
takes something string-ish and yields a string; `size` takes a list or a string
and yields an integer; `plus` takes numerics; `date:` takes a `datetime` or a
`date` and yields a string. This package's grammar has no arrow: a type
expression names a value, never a transformation, and the read check's step 2 is
identity for scalars, so there is nowhere to say "`size` turns a `list` into an
`integer`".

Two ways out, both decisions no record has taken:

1. the filter table lives in the **consumer** (the element package), which maps
   a chain to a required type expression and a produced one and calls
   `satisfies/3` twice - once for the chain's input, once for what the slot
   does with the output. This package stays as it is;
2. this package grows a *kind* vocabulary for slot expectations - something
   like a `:renderable` expectation that every scalar satisfies - which is a
   widening of the closed set, and ADR-0001 decision 4 closes that set.

The spike recommends (1). It requires nothing here, and the filter table is a
Liquid fact, not a datamodel fact. Ask 1 records what (1) needs from this side.

### `default` makes the path optional, and that is a property of the read

`{{ answers.company_name | default: "your team" }}` is a read that tolerates
absence. This package has exactly one place where *promised* is expressed -
`required?` on a declaration's field, which the read check consults on both
sides (`types.ex`, the `covered?/4` clause on `%{required?: false}`) - and it is
a property of the **declaration**, not of the read. A slot that defaults a field
the record declares required is not wrong, and a slot that does not default a
field the record declares optional is the interesting case: today, nothing
reports it, because a path's optionality never reaches the check as part of the
expectation.

The prototype carries `optional?: "default" in filters` on each read, and the
consumer can build the expected shape's `required?` from it. That works with
today's surface and needs nothing here. Ask 2 records the piece that does not:
absence of a **path**, as opposed to absence of a field.

### A dynamic path is unknowable, and should be reported as such

`{{ answers[chosen_key] }}` reads some field of `answers` and the document
cannot say which. The right answer is the one this package already gives for
everything it does not know: unknown is not wrong (decision 12, the "Advisory,
never a gate" section of `index.ex`). The prototype reports the longest static
prefix with `dynamic?: true`; a consumer checks the prefix and stops.

## 5. What the read check reports for a path a later screen writes

Nothing - and that is correct, but it is not the whole answer a screen editor
needs.

`answers.plan` is written by the third screen and read by a slot on the second.
The document declares it, so `Index.declared?/2` is `true`, `Index.type/2` is
`:string`, and the read check says `:identical` against a string expectation.
**The document is position-free**: it declares what the path universe is, not
who writes what when, and no function here takes an ordering.

What does answer the question is `Coverage.missing/3`, against the answers map
as it stands at the moment of render:

```
  Greetable      before screen 1                    {:ok, ["first_name"]}
  Greetable      after screen 1 (name, email)       {:ok, []}
  Contactable    before screen 1                    {:ok, ["first_name", "email", "company_name"]}
  Contactable    after screen 1 (name, email)       {:ok, ["company_name"]}
  Contactable    after screen 2 (company)           {:ok, []}
  Contactable    after screen 2, company skipped    {:ok, ["company_name"]}
```

Coverage is *fill*, not *type*: a key present with a non-`nil` value. That makes
it exactly the run-time question ("is this slot renderable right now?") while
the read check stays the authoring-time question ("could this slot ever be
renderable?"). Two different questions with two different functions, which is
the right split, and it means a screen editor's "this reads an answer the path
has not collected yet" warning is a **static ordering** question that neither
function answers. That is ask 3, and it is the one genuinely new thing a screen
editor needs.

Note the last line: a field the author skipped and a field never asked are the
same `{:ok, ["company_name"]}`. `Coverage` documents this deliberately (fill is
presence with a value), and for a screen path it is the right conflation - an
optional question the visitor skipped leaves the slot just as unrenderable as
one not yet asked.

One shape that is not a gap but reads like one: `Coverage.missing/3` on a
**record** is `:error`, not `{:ok, []}`. A consumer that wants "what has the
visitor not answered yet" over the whole `signup.answers` record has to declare
a shape beside it. The module's moduledoc argues that case (answering *nothing
is missing* for a name that declares no requirements is the one wrong answer),
and the spike agrees with it; it is recorded here because it surprised the
spike, and every consumer will meet it.

## 6. Asks

Each of these is reported to the campaign conductor for filing; none is filed
by this document, and none is worked in SF040.

**Ask 1 - a documented contract for a consumer's own type relation, above the
read check.** The element package will compute "what does this filter chain
require" and "what does it produce" and call `satisfies/3` on the result. Today
nothing says whether that is the intended way to extend the relation or a
misuse of it. `types.ex`'s moduledoc already names one such consumer (the
palette's host relation in `statifier_blocks`, which "runs its own step after
this one returns not-satisfied"). Acceptance: a short section in the `Types`
moduledoc, or a note on ADR-0001, stating that a consumer may wrap the check
with its own pre- and post-relations, may not weaken it, and what it may assume
about `reason()` staying stable. Owning repo: `statifier_datamodel`.

**Ask 2 - a read check answer for an absent path, not just an absent field.**
`satisfies/3` takes two type expressions; a caller holding an undeclared path
has to decide for itself what to pass (the run above passes `:unknown` and gets
`:unknown`, which is right). There is no function that takes an index, a path
and an expectation and answers in one step, so every consumer writes the same
three lines and each one decides independently what an undeclared path means.
Acceptance: either a `Types.satisfies_at/4`-shaped helper over an index, a path
and an expectation - returning the same `reason()`, with an undeclared path
answering `:unknown` - or a README paragraph that names the three lines as the
intended call and closes the question. Owning repo: `statifier_datamodel`.

**Ask 3 - ordering is not in the document, and a screen editor needs it.** "This
slot reads an answer no earlier screen collects" is a real authoring error, and
neither the index nor the read check nor coverage can see it: the document
declares a path universe with no order, and coverage needs a concrete map. The
ordering lives in the block document (the path's screen sequence), so the
question belongs to the walk over that document - `statifier_blocks`' typed
environment - and not here. Acceptance: a bead in `statifier_blocks` for a
reads-before-writes check over the environment walk, taking the declared-path
set from this package and the order from the block tree. Owning repo:
`statifier_blocks`.

**Ask 4 - nothing in the document distinguishes a host-supplied root from a
path a flow writes.** `request.*` is there before any screen runs;
`answers.*` accrues. An editor that wants to offer only already-available paths
in a first-screen slot cannot tell them apart from the document alone. The
scopes are close but not this: `global`, `local` and `event` are about
lifetime, not about provenance. Acceptance: a decision on whether provenance is
a document key at all - a note on an entry is the cheap answer and needs no
code - recorded on ADR-0001 or explicitly declined. Owning repo:
`statifier_datamodel`.

**Ask 5 - `answers` flat versus namespaced is a live question and the document
shape answers it cleanly either way.** Flat (`answers.<element_key>`, one
record) is what this spike declared, and it costs one declaration. Namespaced
per screen would be one record per screen plus an `answers` record whose fields
are those records, which the index also flattens and the read check also
covers - so this package does not prefer one. Acceptance: recorded here as
evidence for whoever rules the question; no work in this repository either way.
Owning repo: none (evidence for Riddler's own open question).

**No ADR is amended by this spike** (campaign consent, clause 9). Ask 1 and
ask 4 are the two that would land on ADR-0001 if taken, and both are asks, not
edits.

## 7. The bead's question, answered

*Can this package be the shared type registry for chart and element contexts?*
Yes, on the evidence here, with one qualification. The document already types
what a chart reads; declaring the answer set as a record types what a slot
reads and what the submit event carries from the same declaration; the index's
`entry_type` feeds `satisfies/3` with no adapter; a record covers a slot's
shape. The qualification is that a Liquid filter chain is a transformation and
this package types values, so the filter table belongs to the element package -
which is the ordinary seam this package already draws for the palette's host
relation, not a new one.

## Reviewer qualifications

One cold review pass ran on this document at the campaign's review gate.
**Pass 1 verdict: QUALIFIED, 5 findings, 0 blocking.** A spike findings
document is merged with its qualifications recorded rather than cured
(campaign SF040 consent, clause 6), so the five are written out here and the
body above is left as the reviewer read it.

1. **Ask 5 is not an ask.** It names no owning repository and no work, so a
   conductor filing the asks has nowhere to put it. It is evidence for the
   open question about what this package declares for a collected answer set,
   and it routes to that question by name rather than to a tracker. Asks 1
   through 4 are well formed, and none of them is a decision this document
   took on its own - ask 2's `satisfies_at/4` is proposed, not added.
2. **"No adapter is needed" is exact for a *declared* path, and the doc does
   not connect that to ask 2.** `Index.type/2` is spec'd `entry_type() | nil`
   and `satisfies/3` is spec'd over `t()`, so an undeclared path's `nil` is
   outside the spec even though the resolver's catch-all maps it to
   `:unknown` at run time. The run passes `:unknown` explicitly rather than
   `nil`, and ask 2 is exactly the request to close that gap; the two
   statements are consistent and the doc leaves the link implicit.
3. **Sections 3 and 5 quote abridged excerpts without saying so.** Section 3
   shows four of nine index rows and drops the `(satisfies?=...)` suffix;
   section 5 shows six of nine coverage rows and moves the record `:error`
   row into prose. Every line shown reproduces exactly, and Appendix C - the
   one labelled verbatim - matches a fresh run byte for byte, as do
   Appendices A and B against their scratch sources.
4. **Section 4's filter, `default` and dynamic-path findings are about a
   Liquid slot richer than the one the parallel fixture work shipped.** That
   fixture's slots, as they stood when this was reviewed, use two plain
   substitutions with no filter, loop or assignment, and the campaign plan
   has the skeleton use a two-line substitution stand-in rather than Liquid
   at all. Appendix C's header says the slot is a Liquid-shaped stand-in
   written for the spike; read section 4 as what a Liquid slot would need,
   not as something observed on the skeleton.
5. **One cite in section 4 is incomplete.** `required?` is read on the held
   side by the `covered?/4` clause the doc names, and on the expected side by
   the `member.required?` filter in `member_wise/4`. The claim that the check
   consults it on both sides is correct; only the cite is half of it.

The reviewer checked every other assertion this document makes about the
package against the code on the branch and found them to hold, and
re-executed the scratch run rather than reading the quotes.

## Appendix A - the element context as a datamodel document

```json
{
  "version": 1,
  "scopes": [
    {
      "scope": "global",
      "label": "Request",
      "entries": [
        {
          "name": "request",
          "path": "request",
          "type": "object",
          "label": "Request",
          "note": "What the host knows about the visit before any screen is answered. Not written by a screen.",
          "fields": [
            {"name": "locale", "path": "request.locale", "type": "string", "label": "Locale", "example": "en-US"},
            {"name": "started_at", "path": "request.started_at", "type": "datetime", "label": "Started at"},
            {"name": "utm_source", "path": "request.utm_source", "type": "string", "label": "Campaign source"}
          ]
        }
      ]
    },
    {
      "scope": "local",
      "label": "This signup",
      "entries": [
        {
          "name": "answers",
          "path": "answers",
          "type": "signup.answers",
          "label": "Answers",
          "note": "Every answer the path has collected, keyed by element key and flat (R10d). Declared AS the record so a text slot's read of it is checked against what the elements promise."
        }
      ]
    },
    {
      "scope": "event",
      "label": "Event",
      "entries": [
        {
          "name": "answers",
          "path": "event.answers",
          "type": "signup.answers",
          "label": "Submitted answers",
          "note": "What the screen's submit event carries, and what core.on_event's capture map writes into the local scope."
        },
        {
          "name": "outcome",
          "path": "event.outcome",
          "type": "string",
          "label": "Outcome",
          "one_of": ["continue", "back", "skip", "timed_out"]
        }
      ]
    }
  ],
  "types": [
    {
      "name": "signup.answers",
      "kind": "record",
      "label": "Signup answers",
      "note": "One field per element key the path declares. A question the path asks on a later screen is a field here just the same: the document is position-free.",
      "fields": [
        {"name": "first_name", "type": "string", "label": "First name", "required?": true},
        {"name": "email", "type": "string", "label": "Email", "required?": true},
        {"name": "company_name", "type": "string", "label": "Company"},
        {"name": "team_size", "type": "integer", "label": "Team size"},
        {"name": "plan", "type": "string", "label": "Plan"},
        {"name": "invites", "type": "list", "item_type": "signup.invite", "label": "Invites"}
      ]
    },
    {
      "name": "signup.invite",
      "kind": "record",
      "label": "Invite",
      "fields": [
        {"name": "email", "type": "string", "label": "Email", "required?": true}
      ]
    },
    {
      "name": "Greetable",
      "kind": "shape",
      "label": "Greetable",
      "note": "What a greeting slot needs and no more.",
      "fields": [
        {"name": "first_name", "type": "string", "label": "First name", "required?": true}
      ]
    },
    {
      "name": "Contactable",
      "kind": "shape",
      "label": "Contactable",
      "note": "What the confirmation screen's slot reads: a name, an address and a company.",
      "fields": [
        {"name": "first_name", "type": "string", "label": "First name", "required?": true},
        {"name": "email", "type": "string", "label": "Email", "required?": true},
        {"name": "company_name", "type": "string", "label": "Company", "required?": true}
      ]
    }
  ]
}
```

## Appendix B - the prototype `paths_read/1`

```elixir
defmodule SdSpike.PathsRead do
  @moduledoc """
  Prototype `paths_read/1`: the datamodel paths a Liquid template reads.

  Walks `Solid.parse/1`'s parsed template and collects every
  `Solid.Variable` that is NOT bound locally by the template itself
  (`{% for %}`, `{% assign %}`, `{% capture %}`, the counter tags). Each
  read carries the dotted path, whether the path is dynamic (a bracket
  access through another variable, or a list index, which the document
  cannot name as a path), and the filter chain applied to it.

  Scratch only: nothing here is a proposal for statifier_datamodel's own
  surface, and `solid` is not a dependency of that package.
  """

  @type read :: %{
          path: String.t() | nil,
          root: String.t(),
          prefix: String.t(),
          dynamic?: boolean(),
          filters: [String.t()],
          optional?: boolean(),
          line: pos_integer()
        }

  @spec paths_read(binary()) :: {:ok, [read()]} | {:error, term()}
  def paths_read(source) when is_binary(source) do
    case Solid.parse(source) do
      {:ok, template} -> {:ok, template.parsed_template |> walk(MapSet.new(), []) |> dedupe()}
      {:error, reason} -> {:error, reason}
    end
  end

  # -- the walk --------------------------------------------------------------

  # A list of nodes is a sequence, and `{% assign %}` / `{% capture %}` bind
  # their target for everything after them, so bindings are threaded left to
  # right rather than passed down unchanged.
  defp walk(nodes, bound, filters) when is_list(nodes) do
    {reads, _bound} =
      Enum.reduce(nodes, {[], bound}, fn node, {acc, bound} ->
        {acc ++ walk(node, bound, filters), bind(node, bound)}
      end)

    reads
  end

  # An output: its filter chain belongs to the variable it wraps, and a
  # filter's own arguments are read in their own right.
  defp walk(%Solid.Object{argument: argument, filters: fs}, bound, _filters) do
    walk(argument, bound, Enum.map(fs, & &1.function)) ++
      Enum.flat_map(fs, fn f -> walk(f.positional_arguments, bound, []) end)
  end

  # `{% for x in <enumerable> %}`: the enumerable is read in the OUTER
  # bindings, the body with `x` bound.
  defp walk(%Solid.Tags.ForTag{} = tag, bound, _filters) do
    inner = MapSet.put(bound, tag.variable.identifier)

    walk(tag.enumerable, bound, []) ++ walk(tag.body, inner, []) ++ walk(tag.else_body, inner, [])
  end

  # `{% assign n = <expr> %}` reads its right-hand side; `n` itself is a
  # binding, not a read, and the list clause above threads it.
  defp walk(%Solid.Tags.AssignTag{} = tag, bound, _filters),
    do: walk(Map.get(tag, :object), bound, [])

  defp walk(%Solid.Tags.CaptureTag{} = tag, bound, _filters),
    do: walk(Map.get(tag, :body), bound, [])

  defp walk(%Solid.Variable{} = variable, bound, filters) do
    if MapSet.member?(bound, variable.identifier), do: [], else: [read(variable, filters)]
  end

  defp walk(%Solid.Text{}, _bound, _filters), do: []
  defp walk(%Solid.Literal{}, _bound, _filters), do: []
  defp walk(nil, _bound, _filters), do: []

  # Everything else - every other tag and every condition node - is walked
  # structurally. A struct is its own map; a map is its values.
  defp walk(%_{} = node, bound, filters), do: node |> Map.from_struct() |> walk(bound, filters)

  defp walk(node, bound, filters) when is_map(node),
    do: node |> Map.values() |> Enum.flat_map(&walk(&1, bound, filters))

  defp walk(_other, _bound, _filters), do: []

  # -- local bindings --------------------------------------------------------

  defp bind(%Solid.Tags.AssignTag{argument: %Solid.Variable{identifier: name}}, bound),
    do: MapSet.put(bound, name)

  defp bind(%Solid.Tags.CaptureTag{argument: %Solid.Variable{identifier: name}}, bound),
    do: MapSet.put(bound, name)

  defp bind(%Solid.Tags.CounterTag{} = tag, bound) do
    case Map.get(tag, :argument) do
      %Solid.Variable{identifier: name} -> MapSet.put(bound, name)
      _not_a_plain_variable -> bound
    end
  end

  defp bind(_node, bound), do: bound

  # -- one read --------------------------------------------------------------

  defp read(%Solid.Variable{} = variable, filters) do
    {segments, dynamic?} = segments(variable.accesses, [variable.identifier], false)
    path = if dynamic?, do: nil, else: Enum.join(segments, ".")

    %{
      path: path,
      root: variable.identifier,
      prefix: Enum.join(segments, "."),
      dynamic?: dynamic?,
      filters: filters,
      optional?: "default" in filters,
      line: variable.loc.line
    }
  end

  # A dot access and a bracketed string access name the same path; an
  # integer index is a list element, which the document types by `item_type`
  # rather than by a path of its own; a bracket through another variable is
  # a path the document cannot name, and everything past it is unknowable.
  defp segments([], acc, dynamic?), do: {Enum.reverse(acc), dynamic?}

  defp segments([%Solid.AccessLiteral{value: value} | rest], acc, dynamic?) when is_binary(value),
    do: segments(rest, [value | acc], dynamic?)

  defp segments([%Solid.AccessLiteral{value: index} | _rest], acc, _dynamic?)
       when is_integer(index),
       do: {Enum.reverse(acc), true}

  defp segments([%Solid.AccessVariable{} | _rest], acc, _dynamic?),
    do: {Enum.reverse(acc), true}

  defp dedupe(reads) do
    reads
    |> Enum.group_by(& &1.prefix)
    |> Enum.map(fn {_prefix, [first | _] = group} ->
      %{
        first
        | filters: group |> Enum.flat_map(& &1.filters) |> Enum.uniq(),
          optional?: Enum.all?(group, & &1.optional?),
          dynamic?: Enum.any?(group, & &1.dynamic?)
      }
    end)
    |> Enum.sort_by(& &1.prefix)
  end
end
```

## Appendix C - the scratch run, verbatim

The text slot the run reads (a Liquid-shaped stand-in written for the spike;
the k1 fixture's own slot may differ):

```liquid
Thanks {{ answers.first_name }} - we sent a confirmation to {{ answers.email | downcase }}.
Company: {{ answers.company_name | default: "your team" }}. Plan: {{ answers.plan }}.
Team of {{ answers.team_size }}. Locale {{ request.locale }}; started {{ request.started_at | date: "%Y-%m-%d" }}.
{% if answers.team_size > 10 %}A member of our team will reach out.{% endif %}
{% for invite in answers.invites %}{{ invite.email }} {% endfor %}
{% assign greeting = answers.first_name | capitalize %}{{ greeting }}
{{ answers[chosen_key] }}
```

```

== 1. paths_read/1 over the k1 text slot

  answers                    dynamic?=true optional?=false filters=[] line=7
  answers.company_name       dynamic?=false optional?=true filters=["default"] line=2
  answers.email              dynamic?=false optional?=false filters=["downcase"] line=1
  answers.first_name         dynamic?=false optional?=false filters=["capitalize"] line=1
  answers.invites            dynamic?=false optional?=false filters=[] line=5
  answers.plan               dynamic?=false optional?=false filters=[] line=2
  answers.team_size          dynamic?=false optional?=false filters=[] line=3
  request.locale             dynamic?=false optional?=false filters=[] line=3
  request.started_at         dynamic?=false optional?=false filters=["date"] line=3

== 2. each path against the index

  answers                    declared?=true type={:declared, "signup.answers"} item_type=nil
  answers.company_name       declared?=true type=:string item_type=nil
  answers.email              declared?=true type=:string item_type=nil
  answers.first_name         declared?=true type=:string item_type=nil
  answers.invites            declared?=true type=:list item_type={:declared, "signup.invite"}
  answers.plan               declared?=true type=:string item_type=nil
  answers.team_size          declared?=true type=:integer item_type=nil
  request.locale             declared?=true type=:string item_type=nil
  request.started_at         declared?=true type=:datetime item_type=nil

== 3. the read check over the held types the index gives

  answers read as Greetable                                      signup.answers -> Greetable              :covers (satisfies?=true)
  answers read as Contactable                                    signup.answers -> Contactable            {:missing, ["company_name"]} (satisfies?=false)
  event.answers read as Contactable                              signup.answers -> Contactable            {:missing, ["company_name"]} (satisfies?=false)
  answers.first_name into a string slot                          string -> string                         :identical (satisfies?=true)
  answers.team_size into a string slot (Liquid stringifies)      integer -> string                        :not_assignable (satisfies?=false)
  answers.team_size into `plus`                                  integer -> integer                       :identical (satisfies?=true)
  request.started_at into `date:`                                datetime -> datetime                     :identical (satisfies?=true)
  answers.plan into an unconstrained slot                        string -> unknown                        :unknown (satisfies?=true)
  the invite record into the loop body's inline expectation      signup.invite -> {email: string}         :covers (satisfies?=true)
  an inline invite read where the record is expected             {email: string} -> signup.invite         :not_assignable (satisfies?=false)
  an undeclared path's type (nil) read as a string               unknown -> string                        :unknown (satisfies?=true)

== 4. coverage: what the answers map does not fill yet, screen by screen

  Greetable      before screen 1                    {:ok, ["first_name"]}
  Greetable      after screen 1 (name, email)       {:ok, []}
  Greetable      after screen 2 (company)           {:ok, []}
  Greetable      after screen 2, company skipped    {:ok, []}
  Contactable    before screen 1                    {:ok, ["first_name", "email", "company_name"]}
  Contactable    after screen 1 (name, email)       {:ok, ["company_name"]}
  Contactable    after screen 2 (company)           {:ok, []}
  Contactable    after screen 2, company skipped    {:ok, ["company_name"]}
  signup.answers coverage of a record               :error

== 5. declared paths, in document order

  request
  request.locale
  request.started_at
  request.utm_source
  answers
  answers.first_name
  answers.email
  answers.company_name
  answers.team_size
  answers.plan
  answers.invites
  event.answers
  event.answers.first_name
  event.answers.email
  event.answers.company_name
  event.answers.team_size
  event.answers.plan
  event.answers.invites
  event.outcome
```
