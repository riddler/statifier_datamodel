# ADR-0004: Event and send payloads: the `events` and `sends` sections, a read check over reads handed in as data, and value conformance

Status: proposed (2026-10-13). It flips to accepted once the code that
implements it has shipped in a published version of this package; this record
does not flip its own status.

The shape of the two sections, the posture for an entry whose type names
nothing, value conformance, and the absence of a dependency on the
expression language were ruled by the operator, 2026-10-12. That an entry
requires `name` and `type` and that `label` and `note` are optional was ruled
by the operator, 2026-10-13. The rules of the read check were decided by the
conductor under a standing consent, 2026-10-12; that an entry's `type` has no
inline spelling at version 1 was decided by the conductor under a standing
consent, 2026-10-13. ADR-0001 gains a dated Amendment, proposed with this
record, for the two document keys and for decision 10's value sentence.

## Context

**What a host has today.** A datamodel document declares the paths an author
writes conditions against, in three scopes, and the named record and shape
types those paths may carry (ADR-0001 decisions 3 and 5). One of the three
scopes is `event`: one scope for every event, whose entries spell their own
`event.` prefix (ADR-0001 decision 3). Nothing in the document says which
events a chart receives, which it sends, or what an event's payload carries.

**What a host asks for.** A host building rich charts wants to say, per event
name, what the payload carries - the value a chart's conditions read under
`_event.data` - and, per send, what an outbound payload carries. With that
written down it wants three answers: whether every entry it wrote names a
type the document declares; whether every path a chart's conditions read
under `_event.data` is one the named event's payload type declares; and
whether a concrete payload map, decoded from JSON or built in Elixir,
conforms to the type its event declares, before it is delivered or sent.

**What the package already answers, and what it does not.** `Types.satisfies/3`
decides a type against a type (ADR-0001 decision 8). `Coverage.missing/3`
decides which required fields of a declared shape a map does not fill, and
deliberately does not check a value's type: "the type of a value is the
expression language's question, not the document's" (ADR-0001 decision 10;
the `Coverage` moduledoc in `lib/statifier_datamodel/coverage.ex` at
`fd86ace`). No function checks a value against a type, and none checks a
path a chart reads against an event's payload.

**What must not move.** ADR-0001 decision 2: the package answers questions
about the document alone, returns facts and never a finding, and a function
that needs the block tree, a palette or a rendering context is a seam drawn
wrong. Decision 6: admission is a total normalizer; a half-written
declaration is dropped, never raised on. Decision 12: nothing here refuses a
document. Decision 13: an additive key leaves `version` at `1`. And the
package takes no runtime dependency (the comment above `deps/0` in `mix.exs`
at `fd86ace`), so it never parses an expression: the paths a condition reads
come from the expression language, and arrive here as data.

## Decision

**1. Two optional top-level keys, `events` and `sends`.** Each is a list of
entries. `events` declares the events a chart receives, by name, and the type
of each one's payload; `sends` declares the events a chart sends, by name,
and the type of the payload each carries. A document without either key
declares no events or no sends, which is the state every document written
before this record is in. The keys sit beside `version`, `scopes` and
`types`; ADR-0001's Amendment of 2026-10-13 adds them to decision 3.

**2. An entry: `name` and `type` required, `label` and `note` optional.**

| Key | Required | Meaning |
|---|---|---|
| `name` | yes | the event name as a chart spells it, a non-empty string |
| `type` | yes | the payload's type expression, a non-empty string (decision 3) |
| `label` | no | the human-readable name a pane renders |
| `note` | no | prose for a reader; carries no contract |

An entry missing `name` or `type`, or carrying either as anything but a
non-empty string, declares nothing: it is dropped, never raised on, which is
ADR-0001 decision 6's posture for a half-written declaration. Each list is
read in order and a repeated `name` keeps its first occurrence, as `types`
does. The two lists are separate: a name may appear in both, and an entry of
one never shadows an entry of the other.

**3. `type` is a spelling, resolved as an entry's `type` is.** It is one of
ADR-0001 decision 4's nine (`object` and `list` among them) or the `name` of
a record or shape the `types` key declares. The closed set is looked at
first, then the declarations, which is the resolution order ADR-0001's
Amendment of 2026-09-06 gives a scope entry's `type`. A spelling that names
neither resolves to `:unknown`, as every undeclared name does in this
package: unknown, not wrong.

At version 1 there is no inline spelling: `type` is a string, never a map
spelling a shape, which is what `Types.parse/2` already reads and the reason
it never returns an inline shape (ADR-0001's Amendment of 2026-09-06 on
inline shapes, arm (c)). An entry carries no `item_type`, so an entry typed
`list` declares a list whose items are unknown. A later record may add an
inline spelling or `item_type`; this one adds neither.

**4. An unresolved type is reported, never refused.** An entry whose `type`
resolves to `:unknown` stays in the index with that type. `unresolved/1` is a
fact query over the index: it answers the entries whose type resolves to
nothing, each section in its own list order. A document with an unresolved
entry indexes and answers every other question exactly as it would without
it. Which unresolved entry is an `:error` to a host, and which is silent, is
the host's to decide (ADR-0001 decision 12).

**5. The payload is what a chart reads under `_event.data`, and the `event`
scope is not it.** The two describe different things and do not overlap:

| | The `event` scope (ADR-0001 decision 3) | The `events` section (this record) |
|---|---|---|
| What it declares | paths every event carries, in the document's own addressing (`event.name`) | per event name, the type of that event's payload |
| How many | one scope for every event | one entry per event name |
| Addressed as | the path the entry spells | `_event.data` and what lies beneath it |
| Contributes to the declared-path set | yes, each entry's path (decision 7) | nothing |

Neither feeds the other. `events` and `sends` contribute no path to
`declared_paths/1` and nothing to `path_types/1`, as `types` contributes none
(ADR-0001 decision 7): a payload's members become checkable through decision
6 below, never as declared paths. An `events` entry's `name` is an event's
name and not a scope entry's `name`, so ADR-0001's carried question, how an
event entry spells `name`, stays carried: it is a question about the scope's
entries, and this record does not answer it.

**6. The read check over reads handed in as data.** A host hands in its
document and a list of reads, each `%{events: [name], path: [segment],
location: term}`: the event names a condition is read under (the
transition's event descriptors), the path the condition reads in
`Predicator.Analysis.references/1`'s form (each segment a string, an integer
for a literal index, or `:dynamic` for a computed key), and a location the
check never reads and passes back. The check answers the reads it reports,
in input order, each with its location. Its rules:

1. **A read rooted at `_event` whose second segment is `data`** is checked,
   for every declared event the read's names match, against that event's
   payload type. A read under several names must be declared on each event
   they match.
2. **Matching is the SCXML token-prefix rule over the declared names.** A
   name matches a declared name equal to it, or one it is a token prefix of
   (`order` matches `order.placed`), and `*` matches every declared event.
   The rule is applied here because the declared names are the document's.
3. **The `_event` system fields are not payload reads.** A read of `_event`
   alone, or of `name`, `type`, `sendid`, `origin`, `origintype` or
   `invokeid` under it, is skipped.
4. **A path beneath `_event.data` is declared by the payload type when each
   segment is.** A string segment names a field of a declared record or
   shape and continues with that field's type; an integer segment descends a
   `list` into its `item_type`; a type that resolves to `:unknown`, or an
   item type that is not known, declares whatever lies beneath it, as
   unknown is permissive in decision 8 of ADR-0001. A bare `object` declares
   no member, which is the reading ADR-0001's Note of 2026-09-07 records for
   the read check; any other scalar declares nothing beneath it; and a
   string segment under a `list`, or an integer segment under anything but
   a `list`, is not declared.
5. **A `:dynamic` segment ends the checked prefix there.** What follows a
   computed key is not checked.
6. **A read whose names match no declared event is reported as such.**
7. **Any other root is checked against the declared paths, and only when the
   document declares one.** The read's string segments, up to the first
   segment that is not a string, joined with `.`, must be in
   `Document.declared_paths/1`'s set; a document declaring no path reports
   nothing for such a read (ADR-0001 decision 12: nothing declared, nothing
   reported). The set holds no element path under a `list` (ADR-0001
   decision 7), which is why an integer segment ends this prefix as
   `:dynamic` does.

The package never parses the expression a read came from and takes no
dependency to do so. The host composes the expression language's
`references/1` over its chart's conditions and hands the reads in, and the
guide shows the few lines that takes. The vocabulary that says *why* a read
is reported is not decided here (see "Open questions carried").

**7. Value conformance.** `conforms/3` is given the declarations, a type
expression and a value, and answers `:ok` or `{:error, mismatches}`, each
mismatch `{path, reason}`. It checks against a declared record, a declared
shape or an inline shape alike: a payload is checked against what its event
declares it carries.

- **`reason` is one of two.** `:missing`: a required field is absent or
  `nil`, which is `Coverage.missing/3`'s fill rule. `{:expected, type}`: the
  value at `path` does not conform to `type`, the type expression it failed.
- **`path` is a list of segments**, a string for a field name and an integer
  for a list index, the form decision 6's reads use without `:dynamic`. The
  value itself is at `[]`.
- **Scalars as a decoded JSON value spells them:** `string` a binary;
  `integer` an integer; `decimal` an integer, a float or a `Decimal` struct;
  `boolean` a boolean; `date`, `datetime` and `duration` an ISO 8601 string
  or the matching Elixir struct; `object` a map; `list` a list whose items
  conform to `item_type` when it is known. A `Decimal` struct is recognised
  by its module name; the package takes no dependency on it.
- **What accepts anything:** `:unknown`, `{:opaque, _}`, and a
  `{:declared, name}` the declarations do not hold, which is a name that
  resolves to nothing.
- **What is not enforced:** a key the type does not name is ignored, because
  every object is open; a field's `one_of` is a hint and is not checked. An
  optional field that is absent or `nil` conforms.
- **Keys and order.** A map's keys are read as the strings the declaration
  spells, as `Coverage.missing/3` reads them. Mismatches come in the type's
  field order, depth first, and a list's items in index order.

`Types.satisfies/3` and `Coverage.missing/3` keep every answer they give;
`conforms/3` is a new function beside them.

**8. Advisory, never a gate.** Every answer here is a fact: an index, a list
of entries, a list of reads, `:ok` or a list of mismatches. Nothing refuses a
document, nothing raises on a malformed entry, and nothing is enforced at run
time. Whether a reported read or a mismatched payload stops a host's
pipeline is the host's to decide (ADR-0001 decision 12).

**9. `version` stays at 1.** Both keys are additive: a consumer that ignores
keys it does not know misreads nothing, which is ADR-0001 decision 13's test
for a bump, and it does not fire.

**10. No dependency.** The package still takes no runtime dependency. The
read check takes reads as data in the expression language's path form, so
the package lands in a host without the expression language, and its
release does not wait on the expression language's.

## The contract as typespecs

Module names are stated so the code that builds them, and the consumers'
citations, can be written now.

```elixir
defmodule StatifierDatamodel.Events do
  # One entry of `events` or `sends`, as indexed: the four keys decision 2
  # reads, `type` resolved by decision 3.
  @type entry :: %{
          name: String.t(),
          type: StatifierDatamodel.Types.t(),
          label: String.t() | nil,
          note: String.t() | nil
        }
  # Each section in list order, first occurrence of a name kept.
  @type t :: %{events: [entry()], sends: [entry()]}

  @spec from_document(term()) :: t()
  @spec fetch(t(), :events | :sends, term()) :: {:ok, entry()} | :error
  # The entries whose type resolves to nothing, each section in list order.
  @spec unresolved(t()) :: t()
end

defmodule StatifierDatamodel.Reads do
  @type segment :: String.t() | integer() | :dynamic
  @type read :: %{events: [String.t()], path: [segment()], location: term()}
  # Not decided by this record: see "Open questions carried".
  @type reason :: term()

  # The reads reported, in input order, each paired with why.
  @spec undeclared(term(), [read()]) :: [{read(), reason()}]
end

defmodule StatifierDatamodel.Conformance do
  @type path :: [String.t() | non_neg_integer()]
  @type reason :: :missing | {:expected, StatifierDatamodel.Types.t()}
  @type mismatch :: {path(), reason()}

  @spec conforms(StatifierDatamodel.Declarations.t(),
                 StatifierDatamodel.Types.t(), term()) ::
          :ok | {:error, [mismatch(), ...]}
end
```

Every function is total over any input and none raises. `from_document/1`
answers both sections empty for a value that is not a document, and
`fetch/3` answers `:error` for a name its section does not hold, because
there an entry would be a false claim.

## Worked example

The library loan. A host's document declares two local paths, the event
scope's one entry, four types, the events a loan chart receives and the one
notice it sends:

```json
{
  "version": 1,
  "scopes": [
    {"scope": "global", "label": "Global",
     "description": "Host-owned. The same for every execution of every chart.",
     "entries": []},
    {"scope": "local", "label": "Chart-local",
     "description": "One per execution. Written by the chart as it goes.",
     "entries": [
       {"name": "copy_id", "path": "loan.copy_id", "type": "string", "label": "Copy"},
       {"name": "due_on", "path": "loan.due_on", "type": "date", "label": "Due on"}
     ]},
    {"scope": "event", "label": "Event",
     "description": "The event being handled.",
     "entries": [
       {"name": "event.name", "path": "event.name", "type": "string", "label": "Event name"}
     ]}
  ],
  "types": [
    {"name": "loans.renewal", "kind": "record", "label": "Renewal",
     "fields": [
       {"name": "copy_id", "type": "string", "required?": true},
       {"name": "due_on", "type": "date", "required?": true},
       {"name": "renewals", "type": "integer", "required?": true},
       {"name": "holds", "type": "list", "item_type": "loans.hold"}
     ]},
    {"name": "loans.hold", "kind": "record", "label": "Hold",
     "fields": [
       {"name": "patron_id", "type": "string", "required?": true}
     ]},
    {"name": "loans.return", "kind": "record", "label": "Return",
     "fields": [
       {"name": "copy_id", "type": "string", "required?": true},
       {"name": "returned_at", "type": "datetime", "required?": true},
       {"name": "condition", "type": "string", "one_of": ["good", "damaged"]}
     ]},
    {"name": "notices.due_soon", "kind": "shape", "label": "Due-soon notice",
     "fields": [
       {"name": "patron_id", "type": "string", "required?": true},
       {"name": "due_on", "type": "date", "required?": true}
     ]}
  ],
  "events": [
    {"name": "loan.renewed", "type": "loans.renewal", "label": "Loan renewed"},
    {"name": "loan.returned", "type": "loans.return", "label": "Copy returned"},
    {"name": "loan.lost", "type": "loans.loss", "label": "Copy reported lost"},
    {"name": "loan.renewed", "type": "object", "label": "Renewed again"},
    {"type": "object", "label": "No name"}
  ],
  "sends": [
    {"name": "patron.due_soon", "type": "notices.due_soon",
     "label": "Due-soon notice", "note": "Sent before the due date."}
  ]
}
```

**The index** (decisions 2-4). `events` holds three entries: `loan.renewed`
typed `{:declared, "loans.renewal"}`, `loan.returned` typed
`{:declared, "loans.return"}`, and `loan.lost` typed `:unknown`, because no
declaration is named `loans.loss`. The second `loan.renewed` is dropped (the
first occurrence wins) and the nameless entry declares nothing. `sends` holds
`patron.due_soon` typed `{:declared, "notices.due_soon"}`. `unresolved/1`
answers `loan.lost`'s entry under `events` and nothing under `sends`; the
document indexes and every other answer stands.

**The declared paths** (decision 5) are `loan.copy_id`, `loan.due_on` and
`event.name`, exactly as without the two sections: `events` and `sends`
contribute none.

**The read check** (decision 6), one read per row, each as a host's
composition of `references/1` hands it in:

| `events` | `path` | Reported? |
|---|---|---|
| `["loan.renewed"]` | `["_event", "data", "due_on"]` | no: `loans.renewal` declares `due_on` |
| `["loan.renewed"]` | `["_event", "data", "holds", 0, "patron_id"]` | no: `holds` is a `list` of `loans.hold`, which declares `patron_id` |
| `["loan.renewed"]` | `["_event", "data", "fine_cents"]` | yes: `loans.renewal` declares no `fine_cents` |
| `["loan"]` | `["_event", "data", "copy_id"]` | no: `loan` matches all three events; two declare `copy_id` and `loan.lost`'s type is unknown |
| `["loan"]` | `["_event", "data", "due_on"]` | yes: `loan.returned`'s `loans.return` declares no `due_on` |
| `["loan.renewed", "loan.returned"]` | `["_event", "data", "returned_at"]` | yes: not declared on `loan.renewed` |
| `["*"]` | `["_event", "data", "copy_id"]` | no: as the `loan` row |
| `["loan.renewed"]` | `["_event", "data", :dynamic, "title"]` | no: the checked prefix ends at `_event.data` |
| `["loan.renewed"]` | `["_event", "name"]` | no: a system field, skipped |
| `["patron.registered"]` | `["_event", "data", "patron_id"]` | yes: the name matches no declared event |
| `[]` | `["loan", "due_on"]` | no: `loan.due_on` is a declared path |
| `[]` | `["loan", "fine_cents"]` | yes: the document declares paths and not `loan.fine_cents` |

**Conformance** (decision 7), against the payload `loan.renewed` declares:

```elixir
conforms(declarations, {:declared, "loans.renewal"},
         %{"copy_id" => "c-0412", "due_on" => "2026-11-02", "renewals" => 1})
#=> :ok

conforms(declarations, {:declared, "loans.renewal"},
         %{"copy_id" => "c-0412", "due_on" => ~D[2026-11-02], "renewals" => 1})
#=> :ok

conforms(declarations, {:declared, "loans.renewal"},
         %{"copy_id" => "c-0412", "due_on" => "next week", "renewals" => nil,
           "holds" => [%{"patron_id" => "p-77"}, %{}], "shelf" => "B3"})
#=> {:error, [{["due_on"], {:expected, :date}},
#             {["renewals"], :missing},
#             {["holds", 1, "patron_id"], :missing}]}
```

`shelf` is not a field of `loans.renewal` and is ignored. Against
`loan.returned`'s type, a `condition` of `"lost"` conforms, because `one_of`
is a hint. Against the notice `patron.due_soon` sends,
`%{"patron_id" => "p-77"}` answers `{:error, [{["due_on"], :missing}]}`, and
against `loan.lost`'s `:unknown` every value answers `:ok`.

## Consequences

- **Additive for every document and every consumer already written.**
  `Index.index/1`, `declared_paths/1`, `path_types/1`, `Types.satisfies/3`,
  `Coverage.missing/3` and every other existing function answer as they do
  today; the sections are read by a module of their own and `index/1` does
  not read them.
- **A host's own `events` or `sends` key is read from now on.** The JSON
  Schema leaves every object open (ADR-0002 decision 7), so a document may
  carry either key today as a host's annotation; once the index lands, that
  key is read under this record. The change that lands the index says so in
  its changelog fragment.
- **The schema file follows.** ADR-0002 decision 9 changes the file "in the
  same request as the amendment's code": the request that lands the index
  adds the two properties to `priv/schemas/datamodel-document.schema.json`
  with a schema test and a dated Note on ADR-0002. This record's request
  changes no code and no schema.
- **A host declaring any path sees every other root checked.** Under rule 7
  of decision 6, a read of a root the document does not declare, such as one
  of the SCXML system variables beside `_event`, is reported once the
  document declares one path. A host that does not want those reads checked
  leaves them out of the list it hands in.
- **The read check's "why" waits for a ruling.** The rules above are decided
  and the input shape is decided; the vocabulary of reasons the answer
  carries is not, and the code that builds the check waits for it.
- **Three changes build this record.** `sd-nyg` builds `Events` (decisions
  1-5) with the schema change; `sd-31h` builds `Reads` (decision 6) and the
  guide that composes it with the expression language; `sd-o58` builds
  `Conformance` (decision 7). This record merges at proposed and flips once
  that code ships in a published version.

## Alternatives considered

- **A map keyed by event name.** Rejected: it loses the list order that every
  other list in the document keeps, and a repeated name would have no first
  occurrence to keep.
- **Namespaced key names** for the two sections. Rejected for the plain
  names, which a host reads beside `types` without a prefix to learn.
- **Refusing an unresolved type at load.** Rejected: the package would gate a
  document for the first time, against ADR-0001 decisions 6 and 12.
- **The expression language as a dependency**, optional with a convenience
  over source strings, or required. Rejected: a runtime dependency here is a
  decision against `mix.exs`'s comment, and a host on an older pin of the
  expression language could not resolve it.
- **Scalars by Elixir struct only.** Rejected: a payload decoded from JSON
  would fail every `date`, `datetime` and `duration`.

## Open questions carried, not resolved here

- **The read check's reasons.** Rule 6 of decision 6 says a read whose names
  match no declared event is reported "as such", and the other rules report
  a path a payload type or the declared paths do not declare; this record
  names neither reason term, nor the spelling of an answer that carries the
  event a path failed on. They are a public vocabulary and wait for a
  ruling; `Reads.reason()` above is a placeholder for it.
- **A read under `_event` naming neither `data` nor a system field.** SCXML's
  `_event` carries the seven fields named in decision 6 and no other, and the
  rules above do not say whether such a read is skipped or reported.
- **Decision 7's scalars beside ADR-0001 decision 4.** Decision 4 says a
  `decimal` "is a string", that there are "no floats", and that a `duration`
  is "an expression-language duration string (`30s`, `1h30m`)". Decision 7
  of this record, as ruled, accepts an integer, a float or a `Decimal` struct
  for a `decimal`, and an ISO 8601 string or a `Duration` struct for a
  `duration`; a value spelled as decision 4 spells it would not conform.
  Whether conformance also accepts decision 4's spellings, or decision 4 is
  amended, is open.
- **How an event entry spells `name`.** Carried from ADR-0001, about the
  `event` scope's entries, and untouched here (decision 5).
- **An inline spelling or an `item_type` in an entry.** Not at version 1
  (decision 3); a later record may add either.
