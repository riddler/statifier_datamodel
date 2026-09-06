# ADR-0001: The datamodel document, re-homed: a typed three-scope declaration with named record and shape types, and the declared-path set as its projection

Status: accepted (2026-09-06). Acceptance is the operator's; this record does
not flip its own status.

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

**7. The declared-path set, by the same total function.** `sb-ADR-0006`
decision 6, verbatim in effect: every entry contributes its own `path` at
every nesting depth and nothing else does; an `object` contributes itself and
its fields'; a `list` contributes itself alone; scope names, labels,
examples, types and `sensitive?` contribute nothing. **`types` contributes
nothing.** A declared name is not a path; a declaration's fields are not
paths. The empty-entry document projects to `MapSet.new()`, which is a host
claim, and `nil` remains *no document supplied*.

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
- **The `one_of` value group on a declaration field.** Decision 9 reads a
  field's `one_of` as a value group that narrows the field, so adding one is
  breaking. If the walk that rules on this record prefers `one_of` to stay a
  pure completion hint on declaration fields as it is on entries, the two
  group rows drop out of the table and nothing else changes.
- **Whether `required?` on a *record* field means anything to the read
  check.** Decision 8 reads the shape side's `required?` and ignores the
  record side's: a record's optional field still covers a shape's required
  field by name and type. Whether an optional record field should cover a
  required shape field at all is a question the first embedder's uptake will
  answer with a real case.

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
