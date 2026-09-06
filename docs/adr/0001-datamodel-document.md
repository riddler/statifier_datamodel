# ADR-0001: The datamodel document, re-homed: a typed three-scope declaration with named record and shape types, and the declared-path set as its projection

Status: accepted (2026-09-06). Acceptance is the operator's; this record does
not flip its own status.
Decision 8 amended - an optional record field does not cover a required shape
field (proposed 2026-09-06, `sd-7bx`; the amendment is the last section of
this record).
Note (2026-09-06, `sd-wj1`): it is the second-to-last section now - the
`sd-wj1` amendment below was appended after it.
Note (2026-09-06, `sd-ght`): that amendment is accepted - its code is on
`main` in `21ca866` and shipped in `v0.2.0`.
Decisions 3, 5, 6, 7 and 9 amended - a field's `one_of` is a completion hint
and never a break, a field going required -> optional is, and a scope
entry's `type` may name a declaration (proposed 2026-09-06, `sd-wj1`; the
amendment is the last section of this record).
Note (2026-09-06, `sd-wj1`): that amendment is accepted - its code lands in
the same change that flips it.
Note (2026-09-06, `sd-906`): it is the second-to-last section now - the
`sd-906` amendment below was appended after it.
Decision 8 and the type-expression grammar of decision 5 amended - a type
expression admits an inline, unnamed shape beside a declared name (proposed
2026-09-06, `sd-906`; the amendment is the last section of this record).
Note (2026-09-06, `sd-n51`): that amendment is accepted - its code is on
`main` in `3116a72`.

Origin: `sb-ADR-0006`, "The datamodel document is a typed, three-scope
declaration, and the declared-path set is its projection", accepted in
statifier_blocks on 2026-08-29. This record re-homes that document here and
extends it by one key. When the code moves, statifier_blocks amends its
ADR-0006 to point at this record; until then `sb-ADR-0006` is the accepted
text and this record is the proposal that succeeds it.

## Context

**What the document is.** A datamodel document is a host's typed description
of the data universe an author writes conditions against: which dotted paths
exist, of what type, in which of three scopes, under what label. `sb-ADR-0006`
defined it, statifier_blocks built its index (`StatifierBlocks.Predicates.
Datamodel`) and the pure half of its reader (`StatifierBlocks.Datamodel`'s
`declared_paths/1` document arm, `candidates_under/2`, `value_candidates/2`),
and three consumers read it today: the editor's undeclared-path advisory, the
declared-path drawer view, and the expression control's candidate list.

**Why it moves.** Two packages now need to read the same document and
neither should have to take the other to do it. statifier_blocks needs it for
the typed environment - a flow-sensitive walk over a block document that
checks each block's declared reads against the types its declared writes put
at datamodel paths. statifier-ui needs it for the expression editor, which
wants the per-path value kind so a condition on an integer path offers the
numeric operators and a condition on a date path offers the relative-date
set. Today statifier_blocks takes statifier-ui as an optional dependency for
that editor; making statifier-ui take statifier_blocks back, for a map it
could derive itself, would close a cycle. The document has no dependency on
the block tree, the compiler or any rendering, so the home that lets both
packages read it without a cycle is a third package that depends on nothing
in the family. That is this one.

**Why it grows one key.** The typed environment needs to name what a write
puts at a path and what a read expects there, and an opaque string per block
type cannot say whether one satisfies the other. The record and shape
declarations that answer that question are declarations about the data
universe, which is what this document already is: one artifact the host
already hands the editor and the compiler, rather than a second one beside
it. The projection to the declared-path set ignores the new key exactly as
it ignores `sensitive?` (`sb-ADR-0006` decision 7): a consumer that needs
types reads the document, never the set.

**What stays behind.** The environment walk needs the block tree - it seeds
from the entry block, reads each block's write signature, merges at branches
- and so it stays in statifier_blocks and consumes this package's read
check. The findings that walk produces, their severity and their rendering
are statifier_blocks' and statifier-ui's. Nothing here produces a finding,
refuses a document, or reaches an engine.

## Decision

**1. A new record here; the origin stays cited; ownership transfers.** This
record does not amend `sb-ADR-0006`: a lettered amendment on a record in
another repository cannot transfer a contract out of that repository. It is
a new record in the owning repository, and by the umbrella's rule - the
repository whose files change owns the decision - the document's shape, the
index, the declared types and the read check, compatibility and coverage are
this repository's call from the moment the code lands here. statifier_blocks
amends its ADR-0006 to say so when its modules are deleted in favour of this
package's. Everything `sb-ADR-0006` decided that this record does not restate
is carried unchanged, in particular its cross-check against `sui-ADR-0006`
(datasets are examples, this document is a declaration; the two share the
word, the addressing and the type floor and nothing else) and its "advisory,
never a gate" stance.

**2. What this package owns and what it refuses to.** This package answers
questions about the document alone: admission and indexing; the declared-path
projection; the declared types and the read check; compatibility of one
declaration against another; coverage of a map against a shape; the
projection to value kinds. It returns facts - a set, an index, a boolean, a
list of names, a map - and never a finding, a severity or a verdict. It does
not walk a block document, render anything, or enforce anything at run time.
A function that needs the block tree, a palette or a rendering context is
evidence that the seam was drawn wrong, and is a stop-and-report rather than
a dependency to add.

**3. The shape.** A datamodel document is a map with three keys:

- `version` - an integer, starting at `1`.
- `scopes` - a list of exactly three scope maps, in order: `global`, `local`,
  `event`. A scope carries `scope`, `label`, `description` and `entries`.
- `types` - optional; a list of declarations (decision 5). A document
  without the key declares no types, which is the state every document
  written against `sb-ADR-0006` is already in.

An **entry** carries the four required keys `name`, `path`, `type`, `label`
and the optional `fields` (for `object`), `item_type` (for `list`), `example`,
`note`, `one_of` and `sensitive?`, with the meanings `sb-ADR-0006` gave them.
Every path is absolute and globally addressable; an event entry spells its
own `event.` prefix.

*[Amended 2026-09-06, with `sd-wj1`: an entry's `type` - and a `list`
entry's `item_type` - may also name a declaration the `types` key declares.
See the last section of this record.]*

**4. Nine types: the origin's eight, plus `date`.** `string`, `integer`,
`decimal`, `boolean`, `datetime`, `duration`, `date`, `object`, `list`. The
set is **closed**, for the same reason as before: a closed set keeps every
rendering table finite. The floor is unchanged - no floats; money is integer
minor units; `decimal` is a string; `duration` is an expression-language
duration string (`30s`, `1h30m`) per `sb-ADR-0006`'s amendment of 2026-09-05;
`datetime` is an ISO-8601 string.

`date` is the one widening, with a real member to name: a card's expiry
month, a signup's date of birth, a settlement date. A `date` value is an
ISO-8601 calendar date string, `2026-09-05`, which is the spelling the
expression language's own date literal reads; which strings parse is
predicator's to define, on the same reasoning the duration amendment gave.
It is a distinct type and not a `datetime` because the expression language
distinguishes them (`:date` and `:datetime` are separate value kinds with
separate literals), and a projection that collapsed them would offer the
wrong operators.

**5. The `types` key: named record and shape declarations.** Each declaration
is a map carrying:

| Key | Required | Meaning |
|---|---|---|
| `name` | yes | the declared name, unique across the list; a dotted string is admitted (`cards.credit_txn`) and carries no path meaning |
| `kind` | yes | `record` or `shape` |
| `label` | yes | the human-readable name a pane renders |
| `fields` | yes | an ordered list of field maps |
| `note` | no | prose for a reader; carries no contract |

A **field** carries `name` (unique among its siblings), `type`, and the
optional boolean `required?` (default `false`, in ADR-0002's optional-boolean
convention), plus optional `label`, `note` and `one_of`. A field's `type` is
one of the nine types above, or the `name` of another declaration. A `list`
field carries `item_type` under the same rule. Declarations may reference
each other; a reference to a name the list does not declare normalizes to
unknown (decision 6) rather than failing admission.

The two kinds keep the roles the typed environment gives them. A **record**
is a fact about what a write puts at a path: the entry block that seeds
`cards.credit_txn` at the subject path, the leaf that writes
`cards.settlement` to its `assign_to`. A **shape** is a constraint a read
places on a path: a leaf that expects `Settleable` where it reads. Identity
is **nominal**: two records with identical fields are two records, and a
record is never read as another record by structure. The one widening in the
system is record-into-shape (decision 8).

*[Amended 2026-09-06, with `sd-wj1`: a field's `one_of` is a completion hint
and never a contract, exactly as it is on an entry. See the last section of
this record.]*

**6. The index, and admission as a total normalizer.** The index over a
document is `StatifierBlocks.Predicates.Datamodel`'s, re-homed, with its
normalization rules carried unchanged and one addition:

- `index/1` admits a map carrying a list under `"scopes"` and returns `nil`
  for anything else, so *not a document* stays distinguishable from *a
  document declaring nothing*; every function taking an index is then total
  by construction.
- Scope names contribute nothing to a path; an entry whose `path` is not a
  non-empty string contributes no path and its `fields` are still walked; a
  `type` or `item_type` outside the closed set normalizes to `nil`, unknown
  rather than wrong; a repeated path keeps its first occurrence; `name` is
  read and stored and nothing here consumes it.
- **The addition:** `types` is indexed to `name -> declaration`, in list
  order, first occurrence winning. A declaration missing `name`, `kind` or
  `fields`, or whose `kind` is neither `record` nor `shape`, declares nothing
  - a half-written declaration is dropped, not raised on. A field whose
  `type` names nothing declared and nothing in the closed set has type
  `nil`.

*[Amended 2026-09-06, with `sd-wj1`: an entry's `type` and `item_type`
resolve against the closed set first and then against `types`, and a
spelling that names neither is `nil` exactly as before. See the last section
of this record.]*

**7. The declared-path set, by the same total function.** `sb-ADR-0006`
decision 6, verbatim in effect: every entry contributes its own `path` at
every nesting depth and nothing else does; an `object` contributes itself and
its fields'; a `list` contributes itself alone; scope names, labels,
examples, types and `sensitive?` contribute nothing. **`types` contributes
nothing.** A declared name is not a path; a declaration's fields are not
paths. The empty-entry document projects to `MapSet.new()`, which is a host
claim, and `nil` remains *no document supplied*.

*[Amended 2026-09-06, with `sd-wj1`: an entry whose `type` names a
declaration contributes its own path and, beneath it, the declaration's
fields, exactly as an inlined `object` contributes its `fields`. `types`
still contributes no path of its own. See the last section of this record.]*

**8. The read check.** Given the declarations, a type `held` at a path and a
type `expected` by a read, `satisfies?/3` is decided in order:

1. either side unknown -> satisfied (unknown stays permissive both ways);
2. identity -> satisfied (the same declared name, the same scalar, or the
   same opaque string - an opaque string a consumer carries that names no
   declaration compares by identity and nothing else);
3. `held` names a record and `expected` names a shape -> satisfied when the
   record's fields **cover the shape's required set**: for every field of
   the shape with `required?: true`, the record has a field of the same
   `name` whose `type` satisfies the shape field's `type` under this same
   check;
4. otherwise -> not satisfied.

That is the whole relation this package defines. There is no record-into-
record structural widening, no union, no inference, and no fifth step: a
consumer that widens further by name - the palette's host relation in
statifier_blocks - runs its own step after this one returns not-satisfied,
in its own package, and this record neither defines nor forbids it.
`satisfies/3` is the same check returning the reason - `:unknown`,
`:identical`, `:covers`, `{:missing, [field names]}`, `:not_assignable` - for
a consumer that renders one.

**9. Compatibility of a redefined declaration.** `breaks/2`, given the
declaration a name had and the declaration replacing it, lists every way the
new one narrows the old one - every reason a read that held under the old
declaration might not hold under the new - deterministically ordered by
field name then by reason:

| Change | Verdict |
|---|---|
| a field removed | breaking |
| a field's `type` changed | breaking |
| a field optional -> required | breaking |
| a required field added | breaking |
| a field's `one_of` value group added | breaking |
| an optional field added | compatible |
| a field required -> optional | compatible |
| a field's `one_of` value group removed | compatible |

A `one_of` value group is compared by value with order ignored, so reordering
one is no change and shrinking one is a group changed, which is breaking on
the same reasoning as a type change. The list is empty when the redefinition
is compatible; a name that is not declared on either side is an `:error`,
never an empty list.

*[Amended 2026-09-06, with `sd-wj1`: the eight-row table above, and the
sentence beneath it about a shrunk value group, are superseded by the
six-row table in the last section of this record - the two `one_of` rows are
gone, and `a field required -> optional` is breaking. The eight rows are
kept here as the text that was accepted; the last section is what `breaks/2`
decides.]*

**10. Coverage of a map against a shape.** `missing/3`, given the
declarations, a shape name and a map, returns `{:ok, names}` - the `name` of
every required field of the shape the map does not fill, in declaration
order - or `:error` when the name is not declared or is not a shape. "Fill"
is presence of the key with a non-`nil` value; this record does not check the
value's type against the field's, because a map here is data a host handed
in and the type of a value is the expression language's question.

**11. Value kinds for an expression editor.** `path_types/1` is one total
projection of the index to `%{path => kind | {:list, kind} | {:one_of,
values}}`, in the expression language's own vocabulary of value kinds:

| Entry | Projects to |
|---|---|
| `type: string` | `:string` |
| `type: integer` or `decimal` | `:number` |
| `type: boolean` | `:boolean` |
| `type: date` / `datetime` / `duration` | `:date` / `:datetime` / `:duration` |
| `type: list` with a scalar `item_type` | `{:list, kind}` |
| any entry carrying a drawable `one_of` | `{:one_of, values}` - the enumeration wins over the kind |
| `type: object`, `type: list` without an `item_type`, an unknown type | absent from the map |

Absence means unknown, not wrong: an editor handed the map treats a path it
does not contain exactly as it treats every path today. The map carries no
labels, scopes or declarations; a consumer that wants those reads the index.

**12. Advisory, never a gate - restated for a package that returns facts.**
An undeclared path is unknown, not wrong; an unsatisfied read is a fact this
package reports and a severity a consumer assigns. Nothing here produces a
finding, refuses a document or changes a verdict. Which of this package's
facts is an `:error`, which an `:info`, and which is silent is decided in the
consumer's own record, argued on its own consumers.

**13. `version` stays at 1.** Adding `types`, `date` and `required?` is
additive: a consumer written against `sb-ADR-0006` that ignores keys it does
not know misreads nothing, which is the rule `sb-ADR-0006` decision 8 adopted
from `sui-ADR-0005`. A bump means a consumer of the old version would
misread the file, and none would.

## The contract as typespecs

Module names are stated so the consumers' citations can be written now; the
campaign that moves the code keeps every public name under
`StatifierDatamodel.*`.

```elixir
defmodule StatifierDatamodel.Index do
  @type type ::
          :string | :integer | :decimal | :boolean
          | :datetime | :duration | :date | :object | :list
  @type scope :: :global | :local | :event | nil
  @type entry :: %{
          path: String.t(), name: String.t() | nil, type: type() | nil,
          label: String.t() | nil, scope: scope(), depth: non_neg_integer(),
          item_type: type() | nil, example: term(), note: String.t() | nil,
          one_of: [term()] | nil, sensitive?: boolean()
        }
  @type t :: %__MODULE__{
          version: integer(),
          entries: %{optional(String.t()) => entry()},
          order: [String.t()],
          declarations: StatifierDatamodel.Declarations.t()
        }

  @spec index(term()) :: t() | nil
  @spec declared_paths(t()) :: MapSet.t(String.t())
  @spec sensitive_paths(t()) :: MapSet.t(String.t())
  @spec entries(t()) :: [entry()]
  @spec fetch(t(), term()) :: {:ok, entry()} | :error
  @spec type(t(), term()) :: type() | nil
  @spec declared?(t(), term()) :: boolean()
  @spec under(t(), term()) :: [entry()]
  @spec path_types(t()) :: %{
          optional(String.t()) =>
            kind() | {:list, kind()} | {:one_of, [String.t()]}
        }
  @type kind :: :string | :number | :boolean | :date | :datetime | :duration
end

defmodule StatifierDatamodel.Declarations do
  @type field :: %{
          name: String.t(),
          type: StatifierDatamodel.Types.t() | nil,
          item_type: StatifierDatamodel.Types.t() | nil,
          required?: boolean(),
          label: String.t() | nil,
          one_of: [term()] | nil
        }
  @type declaration :: %{
          name: String.t(), kind: :record | :shape,
          label: String.t() | nil, fields: [field()]
        }
  @type t :: %{optional(String.t()) => declaration()}

  @spec from_document(term()) :: t()
  @spec fetch(t(), String.t()) :: {:ok, declaration()} | :error
end

defmodule StatifierDatamodel.Types do
  # A type expression: a declared name, one of the nine, an opaque string a
  # consumer carries, or unknown.
  @type t :: {:declared, String.t()} | StatifierDatamodel.Index.type()
           | {:opaque, String.t()} | :unknown
  @type reason ::
          :unknown | :identical | :covers
          | {:missing, [String.t()]} | :not_assignable

  @spec satisfies?(StatifierDatamodel.Declarations.t(), t(), t()) :: boolean()
  @spec satisfies(StatifierDatamodel.Declarations.t(), t(), t()) :: reason()
end

defmodule StatifierDatamodel.Compatibility do
  @type break ::
          {:field_removed, String.t()}
          | {:type_changed, String.t()}
          | {:required_added, String.t()}
          | {:made_required, String.t()}
          | {:group_added, String.t()}

  @spec breaks(StatifierDatamodel.Declarations.declaration(),
               StatifierDatamodel.Declarations.declaration()) :: [break()]
end

defmodule StatifierDatamodel.Coverage do
  @spec missing(StatifierDatamodel.Declarations.t(), String.t(), map()) ::
          {:ok, [String.t()]} | :error
end
```

Every function is total over its admitted input and none raises; the only
`:error` returns are the two that name a declaration that does not exist,
because there an empty list would be a false claim.

*[Note 2026-09-06, with `sd-906`: two entries of this appendix are behind
the amendments below it, which by this record's convention edit no text
above their own headings. `Types.t()` gains the inline shape arm the last
section names, and `Compatibility.break()` reads `{:made_optional, name}`
rather than `{:group_added, name}` since the `sd-wj1` amendment swapped
the member - which is what `lib/statifier_datamodel/compatibility.ex`
already spells. `sd-izx` carries the arm into the code and `sd-n51` flips
the section that names it; whoever next rewrites this appendix wholesale
reconciles both.]*

## Worked shape

Credit-card processing. The scopes are `sb-ADR-0006`'s worked shape with a
`date` entry added; the `types` key is new.

```json
{
  "version": 1,
  "scopes": [
    {
      "scope": "global",
      "label": "Global",
      "description": "Host-owned. The same for every run of every chart.",
      "entries": [
        {
          "name": "limits", "path": "limits", "type": "object", "label": "Limits",
          "fields": [
            {"name": "authorization_window", "path": "limits.authorization_window",
             "type": "duration", "label": "Authorization window", "example": "15m"}
          ]
        }
      ]
    },
    {
      "scope": "local",
      "label": "Chart-local",
      "description": "One per run. Written by the steps of the chart as it goes.",
      "entries": [
        {"name": "amount_cents", "path": "amount_cents", "type": "integer",
         "label": "Amount (minor units)", "example": 42350},
        {"name": "risk_reasons", "path": "risk_reasons", "type": "list",
         "item_type": "string", "label": "Risk reasons",
         "example": ["velocity", "new_device"]},
        {
          "name": "card", "path": "card", "type": "object", "label": "Card",
          "fields": [
            {"name": "brand", "path": "card.brand", "type": "string", "label": "Brand",
             "one_of": ["visa", "mastercard", "amex"]},
            {"name": "last4", "path": "card.last4", "type": "string", "label": "Last four"},
            {"name": "expires_on", "path": "card.expires_on", "type": "date",
             "label": "Expires on", "example": "2028-11-30"}
          ]
        }
      ]
    },
    {
      "scope": "event",
      "label": "Event payload",
      "description": "The payload of the event being handled.",
      "entries": [
        {"name": "event.name", "path": "event.name", "type": "string", "label": "Event name"}
      ]
    }
  ],
  "types": [
    {
      "name": "cards.credit_txn", "kind": "record", "label": "Credit transaction",
      "fields": [
        {"name": "amount_cents", "type": "integer", "required?": true},
        {"name": "currency", "type": "string", "required?": true,
         "one_of": ["USD", "EUR", "GBP"]},
        {"name": "card", "type": "cards.card", "required?": true},
        {"name": "authorized_at", "type": "datetime", "required?": true},
        {"name": "risk_reasons", "type": "list", "item_type": "string"}
      ]
    },
    {
      "name": "cards.card", "kind": "record", "label": "Card",
      "fields": [
        {"name": "brand", "type": "string", "required?": true},
        {"name": "last4", "type": "string", "required?": true},
        {"name": "expires_on", "type": "date", "required?": true}
      ]
    },
    {
      "name": "Settleable", "kind": "shape", "label": "Settleable",
      "fields": [
        {"name": "amount_cents", "type": "integer", "required?": true},
        {"name": "currency", "type": "string", "required?": true},
        {"name": "authorized_at", "type": "datetime", "required?": true}
      ]
    },
    {
      "name": "Refundable", "kind": "shape", "label": "Refundable",
      "fields": [
        {"name": "amount_cents", "type": "integer", "required?": true},
        {"name": "settled_at", "type": "datetime", "required?": true}
      ]
    }
  ]
}
```

What the document decides:

- **The declared-path set** (decision 7) is exactly `limits`,
  `limits.authorization_window`, `amount_cents`, `risk_reasons`, `card`,
  `card.brand`, `card.last4`, `card.expires_on`, `event.name` - nine paths,
  and nothing from `types`.
- **The read check** (decision 8): a leaf expecting `Settleable` where the
  subject path holds `cards.credit_txn` is satisfied - the record's fields
  cover `amount_cents`, `currency` and `authorized_at` by name and type
  (`:covers`). A leaf expecting `Refundable` there is not: `settled_at` is
  missing (`{:missing, ["settled_at"]}`), and the environment walk in
  statifier_blocks reports that at the path it was checked, at whatever
  severity its own record assigns. A leaf expecting `cards.card` where the
  path holds `cards.credit_txn` is not satisfied either (`:not_assignable`):
  both are records and there is no structural widening between records.
- **Compatibility** (decision 9): redefining `cards.credit_txn` with
  `currency` no longer required is compatible; redefining it without
  `authorized_at` breaks with `{:field_removed, "authorized_at"}`, and every
  read that expected `Settleable` on a path holding it would stop holding -
  which is what the list is for. Narrowing `currency`'s value group to
  `["USD"]` is `{:group_added, "currency"}`.
- **Coverage** (decision 10): `missing(declarations, "Settleable",
  %{"amount_cents" => 4200, "currency" => "USD"})` is
  `{:ok, ["authorized_at"]}`; against `"cards.card"` it is `:error`, because
  that name is a record and coverage is a question asked of shapes.
- **Value kinds** (decision 11): `amount_cents => :number`,
  `card.brand => {:one_of, ["visa", "mastercard", "amex"]}`,
  `card.last4 => :string`, `card.expires_on => :date`,
  `limits.authorization_window => :duration`,
  `risk_reasons => {:list, :string}`, `event.name => :string`; `limits` and
  `card` are absent, being objects.

Signup wizard, for the advisory that stays where it was: a host declares
`signup.variant_id` and `signup.step`; a block's path field holds
`signup.variant`. That path is not in the declared-path set, statifier_blocks
anchors one `:info` finding on the field, and nothing in this package knows
or needs to know that a finding was produced.

## Consequences

- statifier_blocks and statifier-ui each take `{:statifier_datamodel,
  "~> 0.1"}` and neither takes the other for the document. statifier_blocks
  deletes `StatifierBlocks.Predicates.Datamodel` and the pure arms of
  `StatifierBlocks.Datamodel`, keeps `findings/4`, `candidates/3` and
  `declared_view/3` (they need a `Document` and a `Palette`), and reads the
  document through this package. statifier-ui takes `path_types/1`'s map as
  the expression editor's assign.
- The publish order on release day follows the dependency edge: this
  package first, then statifier-ui, then statifier_blocks.
- A closed type set still means a host with a value this record cannot type
  declares it as `object` with no fields or leaves it undeclared, and takes
  unknown-ness for it. `date` closes the one gap the first embedder named;
  the next real member is a widening amendment here, not in a consumer.
- The nominal identity rule is a real cost a host will feel: two records
  with the same fields do not satisfy each other, and the host that wants
  them to writes a shape both cover. That is deliberate. Structural
  record-into-record widening was refused rather than deferred, because the
  question "is this record assignable to that one" has a different answer
  in every host and the host relation in statifier_blocks is where a host
  answers it.
- Every open question `sb-ADR-0006` carried is carried here unchanged and is
  not re-resolved by the move: how an event entry spells `name`; name
  collisions across scopes; whether `one_of` is a hint or a claim; delivery
  (assign, sidecar or callback); whether a sui dataset is validated against
  this document. Decision 11's `{:one_of, values}` projection is a *use* of
  the hint, on the same footing as the value candidates statifier_blocks
  already defaults from it, and does not promote it.

## Alternatives considered

- **Keep everything in statifier_blocks and hand statifier-ui a plain map.**
  Lands faster and was the recommendation for the first pass. Rejected as
  the resting state because the map's *derivation* would then live in a
  package that optionally depends on the package consuming the map, and the
  next thing statifier-ui wants from the document - labels, one_of, scopes
  - would either widen the map or close the cycle.
- **A separate `types` artifact beside the document.** Rejected: one more
  input the editor may or may not have, a second delivery question, and a
  declaration that names a field by a path with no document to check the
  path against. One artifact, one delivery.
- **Structural identity for records.** Rejected, not deferred (see
  Consequences).
- **A ninth type `date` folded into `datetime`.** Rejected: the expression
  language distinguishes them and the projection would then offer the
  wrong operators for one of them.
- **A required `types` key.** Rejected: every existing document would stop
  admitting for a key it has no use for yet, which is a version bump for an
  additive change.

## Open questions carried, not resolved here

- **Whether a scope entry's `type` may name a declaration.** This record
  keeps entry types in the closed scalar set: the typed environment is
  seeded by the entry block and by write signatures, not by the document's
  entries, so nothing needs an entry typed by a record yet. Admitting it is
  a small additive amendment when something does.

  *[Answered 2026-09-06, with `sd-wj1`, by the amendment at the end of this
  record: something does, so an entry's `type` and a `list` entry's
  `item_type` may name a declaration. This question is closed.]*
- **The `one_of` value group on a declaration field.** Decision 9 reads a
  field's `one_of` as a value group that narrows the field, so adding one is
  breaking. If the walk that rules on this record prefers `one_of` to stay a
  pure completion hint on declaration fields as it is on entries, the two
  group rows drop out of the table and nothing else changes.

  *[Answered 2026-09-06, with `sd-wj1`, by the amendment at the end of this
  record: the walk prefers the hint, and the two group rows are gone. This
  question is closed, and the last of the three carried here with it.]*
- **Whether `required?` on a *record* field means anything to the read
  check.** Decision 8 reads the shape side's `required?` and ignores the
  record side's: a record's optional field still covers a shape's required
  field by name and type. Whether an optional record field should cover a
  required shape field at all is a question the first embedder's uptake will
  answer with a real case.

  *[Answered 2026-09-06, with `sd-7bx`, by the amendment at the end of this
  record: the uptake case arrived, and an optional record field does not
  cover a required shape field. This question is closed; the two above it
  stay carried.]*

---

## Note (2026-09-06): accepted, and the eight readings the flip records

This record is accepted as of 2026-09-06, after the code it specifies landed
on `main` in four merges: the index and the document reads (`9ba52a1`), the
declared types and the read check (`525ee6c`), `Index.path_types/1`
(`895c7b6`), and compatibility and coverage (`8d29582`). Every claim above
was verified against that tree before the status line moved. The record is
unchanged in every clause; what follows is a note, not an amendment - eight
places where the code answered something this record left silent, or where
two of its own sentences pulled in different directions. From this flip on,
the record reads as each line below says.

- **The Origin paragraph above**, which says `sb-ADR-0006` "is the accepted
  text and this record is the proposal that succeeds it", was written while
  this record was proposed; from this flip on this record is the accepted
  text for the document's shape, the index, the declared types, the read
  check, compatibility and coverage, and `sb-ADR-0006` is its origin.
- **Decision 5, `label`.** The declaration table marks `label` required
  while the typespec below gives it `String.t() | nil` and decision 6's drop
  rule names only `name`, `kind` and `fields`: decision 6 governs admission,
  so a label-less declaration is kept with `label: nil` and "required" in
  the table is what a host is expected to supply, not a condition of being
  indexed.
- **Decision 5, `note`.** A declaration's and a field's optional `note`
  "carries no contract", and the code carries that literally: `note` is read
  by nobody and appears in no indexed declaration or field. (An *entry*'s
  `note`, decision 3's, is indexed and unchanged.)
- **Decision 8, a `list` field's `item_type`.** The read check compares a
  field's `type` and is silent on `item_type`, so a `list` satisfies a
  `list` whatever its items are; narrowing that is an amendment, not a
  reading.
- **Decision 9, `breaks/2`'s signature.** The prose's ":error for a name
  declared on neither side" cannot be expressed by the illustrative typespec
  below, which takes two declarations and returns `[break()]`. The prose
  governs: `breaks/2` takes `declaration() | nil` on each side and returns
  `[break()] | :error`, at the same name and arity.
- **Decision 9, a shrunk value group.** The prose calls shrinking a `one_of`
  "a group changed", and the closed `break()` vocabulary has no
  `:group_changed`: a shrunk group is reported as `{:group_added, name}`,
  which is the tuple for *admits fewer values than before*, and the
  vocabulary stays at five.
- **Decision 9, what is not compared.** `breaks/2` compares a field's
  `type`, its `required?` and its `one_of`, and deliberately compares
  neither `item_type`, nor `label`, nor the declaration's `kind` - the table
  lists the narrowings it decides and nothing outside it is a break.
- **Decision 11, an `object` carrying a `one_of`.** The one_of row is read
  literally and wins over the kind, so an `object` entry carrying a drawable
  `one_of` **is** present in `path_types/1` with its values; the row that
  makes an `object` absent is the fall-through for an entry with no drawable
  enumeration, not a gate on the entry's kind.

---

## Amendment (2026-09-06): decision 8, an optional record field does not cover a required shape field

**Status: accepted (2026-09-06), on the operator's campaign-033 ruling
RQ-033-9.** Narrowing, not additive: it is a breaking change to the read
check, and it is why the release carrying it is a MINOR under `0.x`. No text
above this line is edited by this section, and the amendment takes effect
when `sd-7zl` lands the code and the status flips.

*[Note 2026-09-06, with `sd-ght`: it has. `sd-7zl` landed the code on `main`
in `21ca866` and `v0.2.0` shipped it, so the status line above is accepted
and this section is in effect.]*

### Context

Decision 8 step 3 reads the shape side's `required?` and is silent on the
record side's, so a record whose field may be absent still covers a shape
field that must be present, by name and type alone. The third question in
"Open questions carried" left that reading standing until the first
embedder's uptake produced a real case. It has: the typed environment reads
a record held at a datamodel path against a shape a block requires, and
under the looser reading a document may declare a field optional and still
satisfy a read that cannot proceed without it. The check would then report
satisfied for a document that has not promised the value.

### Decision

**Step 3 of decision 8 reads the record side's `required?` as well.** It now
runs: `held` names a record and `expected` names a shape -> satisfied when
for every field of the shape with `required?: true`, the record has a field
of the same `name`, itself `required?: true`, whose `type` satisfies the
shape field's `type` under this same check.

Everything else in decision 8 stands as written. Steps 1, 2 and 4 are
unchanged; unknown stays permissive both ways; there is still no
record-into-record widening, no union, no inference, and no fifth step.

**The reason is `{:missing, [field names]}`, and there is no new reason.**
A shape field is *missing* from the record when the record declares no field
of that name, and equally when it declares one that is optional: in both
cases the record does not promise the value, which is the one thing step 3
asks. The names list is what a consumer renders, and it names the shape's
fields the record failed to promise, whichever way it failed. Decision 8's
reason vocabulary therefore stays at the five it already names -
`:unknown`, `:identical`, `:covers`, `{:missing, [field names]}`,
`:not_assignable` - and the typespec appendix's `reason()` is unchanged. A
consumer wanting to distinguish *absent* from *present but optional* reads
the record's declaration for the named field; the relation this package
defines does not make the distinction, because nothing it decides turns on
it.

A field the shape marks optional is still not consulted at all, and a record
field the shape does not name is still ignored. This section narrows exactly
one clause and nothing else.

### Consequences

- **Breaking for a document that relied on the looser reading.** A record
  covering a shape today by an optional field stops covering it, and reads
  that were satisfied become `{:missing, [name]}`. The fix in the document
  is one key: mark the field `required?: true` where the record does promise
  the value. The release carrying this is a MINOR under `0.x`, and the
  change is named in its changelog.
- **No vocabulary grows.** No new reason atom, no new key, no signature
  change: `satisfies?/3` and `satisfies/3` keep their names, arities and
  return types, and `reason()` in the typespec appendix is unchanged.
- **Coverage and compatibility inherit it.** Decision 10's `missing/3` is a
  check of a *map* against a shape and is untouched. Decision 9's `breaks/2`
  already lists "a field optional -> required" as breaking and "a field
  required -> optional" as compatible on the old reading of step 3; under
  this amendment the second row is the one that now also narrows what the
  declaration can cover, and it is the redefinition table, not this section,
  that decides what a redefinition reports. This amendment changes neither
  row.
- **The two remaining carried questions are untouched.** Whether a scope
  entry's `type` may name a declaration, and whether a field's `one_of` is a
  hint or a narrowing, stay carried exactly as written.

Implemented by `sd-7zl` (`Types.satisfies/3` and `satisfies?/3` honour the
record field's `required?`, with the worked shape's `cards.credit_txn` and
`Settleable` as the case). This section merges at proposed and flips to
accepted in a separate change once that code is on `main`.

*[Note 2026-09-06, with `sd-ght`: that separate change is this one. The code
is on `main` in `21ca866`, `v0.2.0` (tag at `2c40403`) shipped it, and the
status line at the head of this section now reads accepted.]*

---

## Amendment (2026-09-06): a field's `one_of` is a completion hint, a field going required -> optional is a break, and a scope entry's `type` may name a declaration

**Status: accepted (2026-09-06), on the operator's campaign-034 ruling
RQ-034-4.** Three clauses, two of which move in opposite directions: a
redefinition may now do something it could not (arm a), a document may now
declare something it could not (arm b), and one redefinition that used to be
compatible is now breaking (the row arm a's pass forced). Between them they
are why the release carrying this is a MINOR under `0.x`. No text above this
line is edited by this section, and the amendment takes effect when `sd-wj1`
lands the code and the status flips.

*[Note 2026-09-06, with `sd-wj1`: it has, in the same change - the status
line above reads accepted, and the code it names is the rest of this
request.]*

### Context

Two of the three questions "Open questions carried" left standing are
answered here, and the third clause is a row decision 9's table got wrong
once decision 8 was amended.

**The hint.** `one_of` on an *entry* is read as a completion hint: it lists
the values a host expects, an editor draws them as choices, and a value
control fed from it still admits anything the author types -
`Document.declared_values/1` says exactly that, and the Consequences section
above calls decision 11's `{:one_of, values}` projection a *use* of the hint
that does not promote it. Decision 9 read the same key on a *declaration
field* as a value group that narrows the field, so adding one was breaking
and shrinking one was breaking too. One key meaning
two different things in one document is the defect: an author who narrows a
suggestion list gets a compatibility break for a suggestion, and a consumer
reading a field's `one_of` cannot tell from the key whether it is a promise.

**The row.** Decision 9's table calls `a field required -> optional`
compatible, and it was, under the reading of decision 8 step 3 that ignored
the record side's `required?`. The `sd-7bx` amendment ended that reading:
step 3 now asks the record to promise the value, so a record field that goes
required -> optional stops covering a shape field that requires it, and a
read that held under the old declaration does not hold under the new. That is
precisely what decision 9 says `breaks/2` lists. The table row was left
alone when step 3 moved, and this section moves it.

**The declaration-typed entry.** The first carried question expected an
uptake case before admitting an entry typed by a record, on the ground that
the typed environment is seeded by the entry block and by write signatures
rather than by the document. The case arrived: a host that already declares
`cards.credit_txn` under `types` has to restate every one of its fields as an
inlined `object` entry to get the paths into the index, and the two
statements then drift. The document already has the nominal name; the entry
should be able to use it.

### Decision

**(a) A field's `one_of` is a completion hint, and never a break.** Adding
one, removing one, reordering one, widening one and shrinking one are all
compatible. The key means on a declaration field exactly what it means on an
entry, and nothing in this package reads it as a constraint.

**The row: a field going required -> optional is breaking.** A record field
that stops being required stops promising its value, and decision 8 step 3 as
amended 2026-09-06 stops reading it as covering a shape field that requires
it. The reason a redefinition reports for it is `{:made_optional, name}`.

**Decision 9's table is these six rows:**

| Change | Verdict | Break |
|---|---|---|
| a field removed | breaking | `{:field_removed, name}` |
| a field's `type` changed | breaking | `{:type_changed, name}` |
| a field optional -> required | breaking | `{:made_required, name}` |
| a required field added | breaking | `{:required_added, name}` |
| a field required -> optional | breaking | `{:made_optional, name}` |
| an optional field added | compatible | - |

The `break()` vocabulary stays at five members and swaps one: `:group_added`
is gone, because no `one_of` change is a break, and `:made_optional` takes
its place. Everything decision 9 says around the table stands: `breaks/2`
lists every way the new declaration narrows the old, deterministically
ordered by field name and then by the order this table lists the reasons in;
the list is empty when the redefinition takes nothing away; a name declared
on neither side is `:error`; and `item_type`, `label`, `note` and `kind` are
still not compared.

**(b) An entry's `type`, and a `list` entry's `item_type`, may name a
declaration.** The reference is **nominal**, on decision 5's identity rule:
the entry's type is the declared name, not a copy of the declaration's
fields.

1. **Resolution order is the closed set first, then `types`.** A document
   that declares a type called `"string"` does not shadow the scalar - the
   same precedence `Types.parse/2` already uses for a declaration field. A
   spelling that names neither is `nil`: unknown, exactly as decision 6
   already says, and not a failed admission.
2. **A declaration-typed entry expands beneath its own path.** It contributes
   its own path, and then one path per field of the declaration, spelled
   `<entry path>.<field name>`, at the entry's depth plus one, in the
   declaration's field order. A field that itself names a declaration expands
   again, recursively. This is exactly what an inlined `object` entry does
   with its `fields`, which is the point: a host that spells the object out
   and a host that names the declaration get the same paths.
3. **An expanded path carries what the field carries and nothing else.** Its
   `type`, `item_type`, `label` and `one_of` are the field's; its `name` is
   the field's `name`; its `scope` is the entry's. `example` and `note` are
   absent and `sensitive?` is `false`: a declaration field has no such keys,
   and this record does not invent them. A host that needs them writes the
   entry out inline, which stays admissible.
4. **A cycle discharges rather than recurring.** Declarations may reference
   each other and a host can write a cycle; a declaration already being
   expanded on the same chain of paths is not expanded again, so `index/1`
   stays total over every document. That is the discipline decision 8's check
   already uses for a cyclic read.
5. **A `list` entry still contributes its own path alone.** Decision 7's list
   rule is unchanged: `item_type` names an element type, no record decides an
   index syntax, and there is no element path to expand. A declared
   `item_type` is carried on the entry and expands nothing.
6. **An entry may do both.** An entry that names a declaration *and* carries
   `fields` contributes both sets, with the first occurrence of a repeated
   path winning, which is the rule the index already uses everywhere.
7. **`types` still contributes no path of its own.** Decision 7's sentence
   stands as written: a declared name is not a path, and a declaration's
   fields are not paths. They become paths only beneath an entry that names
   the declaration, and it is the entry that contributes them.

### Consequences

- **`breaks/2`'s vocabulary swaps a member.** A consumer matching
  `{:group_added, _}` stops matching anything and has nothing to replace it
  with, because the change it named is no longer a break; a consumer that
  enumerates the vocabulary handles `{:made_optional, _}`. A redefinition
  that only edits a `one_of` now reports `[]`.
- **A redefinition that relaxes a field now reports a break.** A declaration
  that marks a field `required?: false` where it used to be `true` answers
  `{:made_optional, name}`. That is the redefinition table agreeing with the
  read check rather than contradicting it, and it is what the `sd-7bx`
  amendment's own Consequences section pointed at when it said the
  required -> optional row "is the one that now also narrows what the
  declaration can cover".
- **Arm (b) is additive to every document already written.** An entry whose
  `type` is one of the nine indexes exactly as before, and a document without
  `types` is untouched. What changes is that a spelling outside the closed
  set, which used to be `nil` unconditionally, is now `{:declared, name}`
  when `types` declares it - and still `nil` when it does not.
- **The index reads `types` as well as `scopes`.** Resolving an entry's type
  needs the declarations, so `index/1` builds them and `t:t/0` carries a
  `declarations` key, which is the key the typespec appendix above already
  names. `Index.type/2` may now answer `{:declared, name}` as well as one of
  the nine.
- **Decision 11 inherits arm (b) rather than being amended by it.** An
  expanded path projects by its own field's type, so a scalar field beneath a
  declaration-typed entry is present in `path_types/1` with its kind, a field
  carrying a drawable `one_of` is present with its values, and the
  declaration-typed entry itself is absent from the map exactly as an
  `object` is - it is an entry whose type is not one of the six kinds, which
  is the fall-through row decision 11 already has.
- **Decisions 8 and 10 are untouched.** The read check compares a field's
  `type` and does not read `one_of` at all, and coverage is a check of a map
  against a shape. Neither moves.
- **A MINOR under `0.x`, and the change is named in its changelog.** Arm (a)
  and arm (b) alone would be a patch and a minor addition; the swapped break
  member and the new break on a relaxed field are what make it a MINOR, and
  the fix in a document is to leave the field `required?: true` where the
  record does promise the value.
- **No question is left carried.** All three of "Open questions carried, not
  resolved here" are now answered: two by this section and one by the
  `sd-7bx` amendment above it.

Implemented by `sd-wj1` (`Compatibility.breaks/2`'s six rows, and
`StatifierDatamodel.Index` resolving and expanding a declaration-typed entry,
with the worked shape's `cards.credit_txn` as the case). This section merges
at proposed and flips to accepted in a separate change once that code is on
`main`.

*[Note 2026-09-06, with `sd-wj1`: it merged at proposed in its own request,
and the change that flips it is this one - the code is the rest of this
request rather than a commit already on `main`, on the campaign's clause for
an amendment whose record and code are one bead.]*

---

## Amendment (2026-09-06): a type expression admits an inline, unnamed shape beside a declared name

**Status: accepted (2026-09-06), on the operator's campaign-SF035 ruling
RQ-SF035-1.** Additive: it grows the type-expression grammar by one arm and
decision 8's read check by one step, and takes nothing away from a document
already written. No text above this line is edited by this section, and the
amendment takes effect when `sd-izx` lands the code and the status flips.

*[Note 2026-09-06, with `sd-n51`: it has. `sd-izx` landed the code on `main`
in `3116a72`, so the status line above is accepted and this section is in
effect. No release has shipped it yet.]*

### Context

Decision 5 gives a field's `type` a name-only grammar - "one of the nine
types above, or the `name` of another declaration" - and decision 8 decides
a read over exactly that grammar: unknown, identity, a record covering a
shape, or not satisfied. `StatifierDatamodel.Types.t/0` is the same four
possibilities in a type: a declared name, one of the nine, an opaque string
a consumer carries, or unknown. Every structural statement in the system is
therefore nominal, and a shape that is not declared anywhere cannot be said
at all.

The first two embedders have produced values that are structural and
unnamed. A fan-out's collected element is an envelope map carrying `index`,
`status` and then a `donedata` or a `failure`, assembled by the compiler
rather than declared by the host; a block's declared summary is the same
kind of value, computed at a path the host never wrote a declaration for.
Today a consumer holding one of these has two choices, and both are wrong.
It can spell the value `{:opaque, "..."}`, which compares by identity and
nothing else, so a read against a declared shape the envelope genuinely
covers reports `:not_assignable`. Or it can invent a declaration and inject
it into the document's `types`, which puts a name into the host's document
that the host did not write, gives the value a nominal identity it has no
claim to, and makes the compiler a writer of the datamodel document.

What is missing is a way to say *a map with these members, of these types,
these ones promised* without naming it. That is one arm of the grammar and
one step of the read check, and this section adds them.

### Decision

**(a) `t()` gains an inline shape arm.** A type expression may be
`{:shape, members}`, where `members` is an ordered list of maps, each
carrying exactly three keys:

```elixir
@type member :: %{
        name: String.t(),
        type: t(),
        required?: boolean()
      }

@type t ::
        {:declared, String.t()}
        | {:shape, [member()]}
        | StatifierDatamodel.Index.type()
        | {:opaque, String.t()}
        | :unknown
```

The member spelling mirrors `StatifierDatamodel.Declarations.field/0`'s
three contract-bearing keys and drops the three that carry no contract here:
a member has no `label`, because nothing renders a member's name but the
member's name; no `one_of`, because the `sd-wj1` amendment settled `one_of`
as a completion hint and an inline shape is not a place a host writes hints;
and no `item_type`, because `item_type` is a key of a *declaration field*
and a member's element type has no reader in this package. A member's `type`
is a `t()` and never `nil`: a spelling that resolved to nothing is
`:unknown`, which is the value `nil` already normalizes to everywhere a type
expression is built.

A member whose `name` is not a non-empty string contributes nothing, and a
repeated member name keeps its first occurrence - the rule `Declarations`
already uses for a repeated field name and the index for a repeated path.

**(b) Member order is the reason's order; identity is member-set-wise.**
The list is ordered because `{:missing, [field names]}` is rendered, and
decision 5 gives a declaration an ordered field list so that step 3's
names come out in it; an inline shape names its unpromised members in
member order for the same reason. Order is *not* part of identity: two
inline shapes carrying the same member names with the same types and the
same `required?` are the same type expression however they are ordered, so
step 2 of decision 8 compares an inline shape by member set and not by term
equality. This is the one place the arm's identity is not Elixir's.

**(c) An inline shape is built by a consumer, not written in a document.**
`Types.parse/2` reads a binary spelling and is unchanged: a document's
`type` and `item_type` keys are strings, and there is no document syntax for
an inline shape. Decisions 5, 6, 7, 10 and 11 are therefore untouched - the
`types` key admits what it admitted, the index normalizes what it
normalized, `types` still contributes no path, `missing/3` still checks a
map against a *declared* shape, and `path_types/1` still projects entries.
An inline shape enters this package only as an argument a consumer hands
`Types.satisfies/3` or `satisfies?/3`, exactly as `{:opaque, name}` does
today. Whether a document may one day write one is not decided here; it
would be its own amendment, and it is not needed by either case above.

**(d) Decision 8 gains one step, and it is member-wise.** An inline shape
on the *held* side is a fact about what is there, and on the *expected*
side a constraint a read places. The relation between the two is the one
step 3 already defines, generalized from a record's fields and a shape's
fields to any two member sets: `held` covers `expected` when, for every
member of `expected` with `required?: true`, `held` carries a member of the
same `name`, itself `required?: true`, whose `type` satisfies the expected
member's `type` under this same check. An expected member marked optional
is not consulted; a held member the expectation does not name is ignored.
`covers` and `{:missing, [names]}` are the answers, exactly as in step 3.

The whole relation, by variant:

| `held` \ `expected` | a declared record | a declared shape | an inline shape |
|---|---|---|---|
| **a declared record** | identity only | covers, field-wise (step 3, unchanged) | covers, member-wise (new) |
| **a declared shape** | identity only | identity only | not assignable (new, and it is the old answer) |
| **an inline shape** | not assignable (new) | covers, member-wise (new) | covers, member-wise (new) |

Read down the rightmost column and across the bottom row: a record covers an
inline shape, an inline shape covers a declared shape, and two inline shapes
compare structurally. The two refusals are deliberate. An inline shape never
satisfies a *declared record*, because a record's identity is nominal and an
inline shape has no name to be that record by - decision 5's nominal rule is
untouched. A *declared shape* held never covers anything but itself, inline
or declared, because a shape is a constraint and not a fact about what is
there, which is what step 3 has always said by admitting only a record on
the held side.

Steps 1, 2 and 4 stand as written: unknown is permissive both ways and is
still decided first, so any inline shape read against `:unknown` in either
direction is satisfied; identity is step 2 (by member set, per arm b); and
anything the table does not satisfy is `:not_assignable`.

**A member's type recurses under the same check**, so an inline shape may
carry a scalar, a declared name, another inline shape, an opaque string or
`:unknown`, to any depth. A member whose type is `:unknown` is satisfied
both ways by step 1, which is how a field with an unresolvable type behaves
today. Termination is unchanged: an inline shape is a finite term and
cannot reference itself, so it adds nothing to the cycle discipline; the
`seen` set decision 8's check already carries is keyed on a pair of
*declared* names, an inline shape puts no pair into it, and a declared name
re-entered on the same chain still discharges as covered.

**The reason vocabulary does not grow.** `:unknown`, `:identical`,
`:covers`, `{:missing, [field names]}` and `:not_assignable` are still the
five, and `t:StatifierDatamodel.Types.reason/0` is unchanged. A consumer
that wants to know *which* side was inline reads the type expression it
passed in.

**(e) What an inline shape cannot do.** Three exclusions, each a
consequence of its being unnamed rather than a restriction added on top:

1. **It cannot be referenced by name.** It has no `name`, it is never an
   entry of the `types` key, and no `{:declared, name}` resolves to one.
   `StatifierDatamodel.Declarations.t/0` is still a map of *declarations*,
   and `fetch/2` never answers with an inline shape.
2. **It carries no `one_of`.** Neither the shape nor any member has the key.
   `one_of` is a completion hint an editor draws from a document (the
   `sd-wj1` amendment), and an inline shape is not written in a document.
3. **It is not a declaration entry, and never widens into one.** It has no
   `kind`: it is neither a record nor a shape in decision 5's nominal sense,
   and the table in (d) is the whole of what it may be read as. In
   particular there is no rule by which an inline shape becomes the record
   it structurally resembles.

**(f) Decision 9's six-row table gains no row.** `breaks/2` compares two
*declarations*, whose field types come from `Types.parse/2`, and (c) leaves
`parse/2` reading only a binary spelling: no inline shape can appear on
either side of a redefinition, so there is no narrowing for a row to name.
The six rows and the five `break()` members stand exactly as the `sd-wj1`
amendment left them.

Stated for the amendment that would admit a document spelling: an inline
shape differing in any member is a different type expression under (b), so
it would report `{:type_changed, name}` on the field carrying it, under the
row that already exists. That is coarse - adding an optional member to an
inline shape takes nothing away and would still report a break - and
refining it would need a new `break()` member. This section adds neither
the row nor the member, and names the coarseness so the later amendment
does not rediscover it.

**(g) Value kinds are unchanged.** Decision 11's projection is untouched in
both its input and its output. A path typed by an inline shape - were a
document ever to spell one - is absent from `path_types/1`, on the same
fall-through row that makes an `object` absent: it is not one of the six
kinds an expression editor draws. No kind is added, none is renamed, and
the expression language's vocabulary does not move.

### Worked example

Card processing, and the case that forced the arm. A fan-out authorizes a
chunk of cards and each child answers with an envelope; the parent's
collected element is that envelope, typed by the compiler:

```elixir
chunk_envelope =
  {:shape,
   [
     %{name: "index", type: :integer, required?: true},
     %{name: "status", type: :string, required?: true},
     %{
       name: "donedata",
       type:
         {:shape,
          [
            %{name: "authorized_count", type: :integer, required?: true},
            %{name: "declined_count", type: :integer, required?: true}
          ]},
       required?: false
     }
   ]}
```

Nothing here is declared: the host's document declares `cards.credit_txn`
and `Settleable`, not this. The document does declare the summary a
downstream leaf reads, as a shape:

```json
{
  "name": "ChunkSummary",
  "kind": "shape",
  "label": "Chunk summary",
  "fields": [
    {"name": "authorized_count", "type": "integer", "required?": true},
    {"name": "declined_count", "type": "integer", "required?": true}
  ]
}
```

Three reads, one per new cell of the table in (d):

| Read | `held` | `expected` | Answer |
|---|---|---|---|
| the envelope's `donedata` against the declared summary | the inner inline shape | `{:declared, "ChunkSummary"}` | `:covers` - both required members are promised and their types are identical |
| a declared record written back over the summary's path | `{:declared, "cards.chunk_summary"}`, a record with the same two required fields | the inner inline shape | `:covers` - the record promises both members |
| the envelope against another envelope | `chunk_envelope` | the same three members, `donedata` first | `:identical` - identity is member-set-wise, so the reordering is no difference |

And one refusal: the whole envelope read against `{:declared, "ChunkSummary"}`
is `{:missing, ["authorized_count", "declined_count"]}`, because the
envelope's own members are `index`, `status` and `donedata` - the summary is
one member down, and this package widens nothing to find it.

### Consequences

- **Additive for every document and every consumer already written.** No
  document spelling changes, `parse/2` is unchanged, no reason atom is added
  or removed, and no function gains or loses an argument. A consumer that
  never builds an inline shape sees the same answers it sees today, because
  the new step is reachable only from an argument only such a consumer
  passes. The release carrying it is a MINOR under `0.x` on the grown
  grammar, not on a break.
- **`satisfies/3` and `satisfies?/3` keep their names, arities and return
  types**, and gain a new admissible value in the `held` and `expected`
  positions. `Types.to_string/1` renders the new arm; how it renders is the
  code's call, and this record requires only that the rendering is a
  rendering and not an identity, which is what that function already
  promises.
- **Step 2 stops being term equality.** Comparing an inline shape by member
  set rather than by term is the one behavioural subtlety in the arm, and it
  is where `sd-izx` will earn a test: two inline shapes differing only in
  member order are `:identical`, and a `{:missing, ...}` names members in
  the *expected* side's order.
- **The consumers spell it, and this record decides nothing for them.**
  statifier_blocks' typed environment is where a compiler-assembled value
  acquires a type, and its ADR-0011 - which already takes its read check
  from this record's decision 8 rather than defining a second one - will
  cite this arm's spelling in an amendment of its own; statifier-ui reads
  whatever the environment holds. What either package builds an inline
  shape *for*, when it prefers a declaration, and what severity it assigns
  an unsatisfied read are decisions in their own records, on this package's
  stance that an unsatisfied read is a fact and not a verdict (decision 12).
- **One question is opened, deliberately.** Whether a document may write an
  inline shape - a `type` key that is a map rather than a string - is not
  answered here, because neither embedder needs it and admitting it would
  move decisions 5, 6, 7 and 9 at once. It is carried, not resolved.

Implemented by `sd-izx` (`Types.t/0`'s arm, step 2's member-set identity and
decision 8's member-wise step, with the chunk envelope above as the case).
This section merges at proposed and flips to accepted in a separate change
(`sd-n51`) once that code is on `main`.

*[Note 2026-09-06, with `sd-n51`: that separate change is this one. The code
is on `main` in `3116a72`, and the status line at the head of this section
now reads accepted.]*
