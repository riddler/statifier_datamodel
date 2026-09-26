# ADR-0002: The datamodel document ships a JSON Schema - draft-07, hand-written, advisory, never the admission rule

Status: proposed (2026-09-26). Acceptance is the operator's; this record does
not flip its own status.

Ruled by the operator, 2026-09-26: this package's own document gets a JSON
Schema, written by hand against a draft-07 validator, with a test that pins it
to the index. This record decides what that file is, what it is not, and when
it changes. ADR-0001 is not amended: every decision it makes stands, and this
record adds decisions it does not make.

## Context

**What a host has today.** A host that writes a datamodel document learns
whether it is well-formed in one way only: by handing it to
`StatifierDatamodel.Index.index/1` and reading what comes back. That function
is ADR-0001 decision 6's total normalizer - it admits any map carrying a list
under `"scopes"` and normalizes everything else away rather than refusing it
(`lib/statifier_datamodel/index.ex`, `index/1`, read at `7ede3a2`). A scope
named `"globel"`, a `sensitive?` spelled `"true"`, a declaration whose `kind`
is `"recrod"` - each indexes without a word, and each silently loses what the
host meant: the scope's entries index with `scope: nil`, the flag reads
`false`, the declaration declares nothing. That is the right behaviour for the
package, and it is exactly why the package cannot tell a host that the
document it wrote is not the one ADR-0001 describes.

**What a host asks for.** An authoring tool, a CI job over a host's
checked-in documents, or an editor in another language wants to check a
document against the shape ADR-0001 decisions 3-5 and 13 specify *before*
anything indexes it, in whatever language the tool is written in. A JSON
Schema is the one artifact every such tool already reads. A schema generated
from the code would describe what `index/1` tolerates, which is nearly
everything; what a host wants described is what ADR-0001 says a document
*is*, which only a hand-written file states.

**What must not move.** ADR-0001 decision 12 keeps this package advisory:
nothing here produces a finding, refuses a document or changes a verdict.
Decision 6 keeps admission total: `nil` for *not a document*, an index for
everything else. A schema that the package itself enforced would turn a
description into a gate and change what `index/1` answers for documents hosts
already hold. And `mix.exs` records that a runtime dependency added here is a
decision to record (`mix.exs`, the comment above `deps/0`, read at
`7ede3a2`); a validator is not a runtime need of a package that never
validates.

## Decision

**1. The file, its draft, and its path.** The package ships one JSON Schema,
`priv/schemas/datamodel-document.schema.json`, written against JSON Schema
**draft-07** (`"$schema": "http://json-schema.org/draft-07/schema#"`).
`priv/schemas` is added to the Hex package's `files:` list
(`mix.exs`, `package/0`, read at `7ede3a2`), so the file is in the tarball a
host fetches and not only in the repository.

**2. Hand-written, and pinned by a drift test.** The file is written by hand
from ADR-0001 and its amendments, never generated from the code. A generator
would describe the normalizer; the record describes the document, and the two
differ on purpose (decision 4 below). What keeps the hand-written file honest
is a test, not a generator: the nine type spellings the file lists under
`definitions` are each checked to index to a non-`nil` type through
`StatifierDatamodel.Index.type/2` - which takes an index and a *path*, so the
test builds one entry per spelling and asks for that entry's path - and one
spelling outside the nine is checked to index to `nil`. The closed set lives
in `index.ex`'s private `@types` map (read at `7ede3a2`); a spelling added to
either side without the other turns that test red.

**3. The reader: `StatifierDatamodel.Schema`.** One module, two functions:
`path/0`, the absolute path of the file inside the installed application's
`priv` directory, and `json/0`, the file's contents as a binary, embedded at
compile time with `@external_resource` so that reading it touches no disk at
run time. `json/0` returns the text, not a decoded map: the package decodes no
JSON anywhere, and a host decodes it with the decoder it already has. Nothing
in the package calls either function; they exist so a host finds the file
without knowing the package's install layout.

**4. Advisory, never admission.** The schema describes the well-formed
document; `index/1` stays the admission step. The package never calls the
schema, never validates a document against it, and changes no answer any
function gives: a document the schema rejects indexes exactly as it does
today, and a document the schema accepts indexes exactly as it does today.
Because admission refuses nothing but a non-document, there is no decoder for
the schema to match exactly - the schema is deliberately *stricter* than
`index/1`, and that gap is the thing a host checks for. This is decision 12 of
ADR-0001 applied to a new artifact: a rejection by the schema is a fact a host
reads and a severity a host assigns, never a verdict this package issues.

**5. What the schema requires.** Read from ADR-0001 decisions 3-5 and 13 and
the amendments that edit them:

- **The document** is an object requiring `version` and `scopes`; `types` is
  optional. `version` is the integer `1` (`"const": 1`).
- **`scopes`** is an array of exactly three scope objects, in the order
  `global`, `local`, `event`: draft-07 tuple `items` with `minItems` and
  `maxItems` of `3`, each position fixing its `scope` with `const`. A scope
  requires `scope`, `label`, `description` and `entries`; `entries` is an
  array of entries.
- **An entry** requires `name`, `path`, `type` and `label`, each a string.
  Its optional keys are `fields` (an array of entries, recursively),
  `item_type` (a string), `example` (any JSON value), `note` (a string),
  `one_of` (an array) and `sensitive?` (a boolean).
- **`types`** is an array of declarations. A declaration requires `name`,
  `kind`, `label` and `fields`; `kind` is `record` or `shape`; `note` is an
  optional string. A declaration's `fields` is an array of fields.
- **A field** requires `name` and `type`, each a string; its optional keys
  are `required?` (a boolean), `item_type` (a string), `label` and `note`
  (strings) and `one_of` (an array).

A declaration's `label` is required here though a label-less declaration
still indexes: ADR-0001's flip Note of 2026-09-06 reads decision 5's
"required" as what a host is expected to supply and not a condition of being
indexed, and the schema states what a host is expected to supply.

**6. `type` is a string, and the nine are listed beside it.** An entry's
`type` and `item_type`, and a field's, may be one of the nine closed
spellings (ADR-0001 decision 4) or the name of a declaration the `types` key
declares (ADR-0001's amendment of 2026-09-06 that lets an entry name a
declaration). A draft-07 schema cannot check a name against the document's
own `types` list, so the schema types these keys as strings and lists the
nine under `definitions` as a named enumeration, which is what the drift test
of decision 2 reads. A document spells no inline shape: ADR-0001's amendment
admitting inline shapes gives them no document syntax (its arm (c)), so a
`type` that is an object is not a well-formed document and the schema says so
by requiring a string.

**7. Every object is open.** No object in the schema sets
`"additionalProperties": false`. ADR-0001 decision 13 makes every addition to
the document additive because a consumer ignores keys it does not know; a
schema that refused unknown keys would make a host's own annotation - or the
next additive key this package decides - a validation failure, which is the
misreading decision 13 says an addition must not cause.

**8. `$id` is keyed on the document `version`.** The file's `$id` is
`https://github.com/riddler/statifier_datamodel/schemas/datamodel-document/v1.schema.json`:
an identifier, never fetched, whose `v1` is the document `version` the file
describes. It names no package version, because a package release that
changes nothing the document admits does not change the schema's identity.

**9. When the file changes: the versioning rule.** A `version` bump - the
change ADR-0001 decision 13 reserves for one a consumer of the old version
would misread - ships a *second* file beside this one, with its own `$id`
keyed on the new version; the version-1 file is not edited into it, because
documents written at version 1 keep existing. How the reader names the second
file is decided with the bump, not here, and until then `path/0` and `json/0`
answer version 1. Within version 1, the file changes only when a record
amendment changes what the document admits, and it changes in the same
request as the amendment's code, with a changelog line, because a change to
what the document admits is breaking for every consumer holding one
(`changelog.d/README.md`, read at `7ede3a2`).

**10. The validator is test-only.** The package's own tests validate against
the file with `ex_json_schema ~> 0.11`, declared `only: :test`: it lands in
`mix.lock` and in no host's dependency tree. This is not a runtime dependency
and so not the decision `mix.exs` asks to be recorded; it is named here only
so the reader of this record knows which validator the drift and fixture tests
run under. A host validates with whatever draft-07 validator its own language
has.

## The contract as typespecs

```elixir
defmodule StatifierDatamodel.Schema do
  # The absolute path of priv/schemas/datamodel-document.schema.json in the
  # installed application.
  @spec path() :: String.t()

  # The same file's contents, embedded at compile time; the JSON text, not a
  # decoded map.
  @spec json() :: String.t()
end
```

The schema file, in outline (the file is the text; this is its skeleton):

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/riddler/statifier_datamodel/schemas/datamodel-document/v1.schema.json",
  "type": "object",
  "required": ["version", "scopes"],
  "properties": {
    "version": {"const": 1},
    "scopes": {
      "type": "array",
      "minItems": 3,
      "maxItems": 3,
      "items": [
        {"allOf": [{"$ref": "#/definitions/scope"}, {"properties": {"scope": {"const": "global"}}}]},
        {"allOf": [{"$ref": "#/definitions/scope"}, {"properties": {"scope": {"const": "local"}}}]},
        {"allOf": [{"$ref": "#/definitions/scope"}, {"properties": {"scope": {"const": "event"}}}]}
      ]
    },
    "types": {"type": "array", "items": {"$ref": "#/definitions/declaration"}}
  },
  "definitions": {
    "closed_type": {
      "enum": ["string", "integer", "decimal", "boolean", "datetime",
               "duration", "date", "object", "list"]
    },
    "scope": {"...": "scope, label, description, entries"},
    "entry": {"...": "name, path, type, label; fields, item_type, example, note, one_of, sensitive?"},
    "declaration": {"...": "name, kind, label, fields; note"},
    "field": {"...": "name, type; required?, item_type, label, note, one_of"}
  }
}
```

The `"..."` members stand for the keys decision 5 lists; the definition names
are what a test or a host's tool may cite.

## Worked example

Credit-card processing. The worked shape of ADR-0001 validates against the
schema and indexes as that record says. Four near-misses show the two
answers diverging, which is the point:

| Document | The schema | `index/1` |
|---|---|---|
| ADR-0001's worked shape, unchanged | valid | an index; nine declared paths |
| the same, with the `event` scope dropped | invalid: `scopes` has two items | an index; the eight paths of the other two scopes |
| the same, with `card.last4` marked `"sensitive?": "true"` | invalid: `sensitive?` is not a boolean | an index; `card.last4` is not in `sensitive_paths/1` |
| the same, with `Settleable`'s `kind` spelled `"shap"` | invalid: `kind` is neither `record` nor `shape` | an index; `Settleable` is not declared, and a read expecting it resolves the name as opaque |
| the same, with `"version": 2` | invalid: `version` is not `1` | an index whose `version` is `2` |

And one document the schema accepts on purpose: a local entry
`{"name": "txn", "path": "txn", "type": "cards.credit_txn", "label":
"Transaction"}`. Its `type` is not among the nine, but it is a string, and the
document's `types` key declares `cards.credit_txn` - so the schema accepts it
and `index/1` types the path `{:declared, "cards.credit_txn"}`, expanding the
record's fields beneath it. Had the document declared no such type, the schema
would still accept the entry (it cannot see the `types` list), and `index/1`
would type the path `nil`: unknown, not wrong, which is the stance both keep.

In every row the index is the one `index/1` gives today. A host that wants the
schema's answer asks a validator; the package never does.

## Consequences

- A host can check a document against ADR-0001's shape in any language before
  handing it over, and a document that silently lost a scope, a flag or a
  declaration to normalization is now a failure a host can see.
- Nothing any function in this package answers changes. A host that never
  opens the file sees no difference but a larger tarball.
- Two descriptions of the document now exist - the record and the file - and
  the drift test covers only the nine spellings. A key added to the document
  by a later amendment and not to the file is caught by review of that
  amendment's request, which decision 9 requires to carry the file's change,
  not by a test.
- The schema cannot express the two cross-references a well-formed document
  also keeps: that a declared-name `type` names something in `types`, and
  that a path is unique. Both stay `index/1`'s to normalize and a consumer's
  to report, as ADR-0001 left them.
- A `version` bump now costs a second schema file as well as the record that
  makes it.
