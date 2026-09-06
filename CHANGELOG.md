# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for unreleased work are not written here directly. Each issue drops a
fragment in [`changelog.d/`](changelog.d/README.md); the fragments are assembled
into a version section at release. See that README for the format and for when a
change warrants an entry at all.

## [0.4.0] 2026-09-06

A type expression grows one arm. A consumer holding a structural value the
host never declared can now say what it holds inline, `{:shape, members}`,
instead of inventing a declaration in the document to point at; the read check
decides an inline shape against a declaration and against another inline shape
member-wise, and identity for that arm is member-set-wise rather than by term.
Nothing a document spells changes, and a document that declares only named
types reads exactly as it did, which is what makes this arm additive - the
release is a MINOR under `0.x` because the type expression a caller matches on
admits a shape it did not before. Beside it, `Compatibility.breaks/2` now
documents the first element of a break as the *kind*, the row of the
redefinition table the break came from, so a `case` over the five kinds is
exhaustive without re-deriving from the two declarations why a row broke. The
inline shape arm is recorded in the sd-ADR-0001 amendment, accepted on the
operator's campaign-SF035 ruling.

### Added

- A type expression admits an inline, unnamed shape, `{:shape, members}`, so a
  consumer holding a structural value the host never declared can say what it
  holds without inventing a declaration. The read check decides it against a
  declaration and against another inline shape member-wise, and `to_string/1`
  renders it.

### Changed

- A break from `Compatibility.breaks/2` documents its first element as the
  *kind*: the row of the redefinition table the break came from. The five
  kinds are unchanged and the vocabulary is closed at them, so a `case` over
  `:field_removed`, `:type_changed`, `:made_required`, `:required_added` and
  `:made_optional` is exhaustive and a host need not re-derive from the two
  declarations why a row broke. No result changes shape or value.
- Identity in the read check is member-set-wise for an inline shape: two
  inline shapes carrying the same members in a different order are the same
  type expression. Every other arm still compares by term, no document
  spelling changes, and a document that declares only named types reads
  exactly as it did.

## [0.3.0] 2026-09-06

What `Compatibility.breaks/2` reports changes, and an entry's type may now
name a declaration. A declaration field's `one_of` is a completion hint and
never a break, so `{:group_added, name}` is gone; in its place a record field
going required -> optional is a break, `{:made_optional, name}`, which is what
0.2.0's stricter read check made it. Beside them, an entry's `type` - and a
`list` entry's `item_type` - may name a declaration the document's `types` key
declares, and `Index.type/2` answers `{:declared, name}` for one. A caller
matching on the tuple that is gone stops matching, which is why this release is
a MINOR under `0.x`. Both arms are recorded in the sd-ADR-0001 amendment
accepted on the operator's campaign-034 ruling.

### Added

- An entry's `type`, and a `list` entry's `item_type`, may name a declaration
  the document's `types` key declares: the entry carries `{:declared, name}`
  and contributes the declaration's fields beneath its own path, exactly as
  an inlined `object` entry contributes its `fields`. A spelling that names
  no declaration and nothing in the closed set is still unknown.

### Changed

- A declaration field's `one_of` is a completion hint and never a break:
  `Compatibility.breaks/2` reports nothing for a value group added, removed,
  reordered, widened or shrunk. Match on `{:made_optional, name}` where you
  matched on `{:group_added, name}`, which is gone.
- A record field going required -> optional is now a break,
  `{:made_optional, name}`: an optional field stopped covering a required
  shape field when the read check was amended. Mark the field
  `required?: true` in the redefinition wherever the record does promise the
  value, and the redefinition stays compatible.
- `StatifierDatamodel.Index` carries the document's declarations, so
  `Index.type/2` answers `{:declared, name}` as well as one of the nine
  types.

## [0.2.0] 2026-09-06

A stricter read check, and nothing else. An optional record field no longer
covers a required shape field: step 3 of ADR-0001's decision 8 now reads the
record side's `required?` as well as the shape side's, so a document that
declared a field optional and leaned on the looser reading gets `{:missing,
[name]}` where the check used to answer satisfied. That is a narrowing of
what the read check accepts and so a breaking change for a document holding
the looser reading, which is why this release is a MINOR under `0.x`. The
ruling is recorded as the amendment to sd-ADR-0001 that closes the third of
the questions the record carried; that section stands at proposed until it
is flipped separately.

### Changed

- The read check is stricter: a record field the document declares optional
  no longer covers a shape field the document marks required, so a read that
  was satisfied now answers `{:missing, [name]}`. Breaking for a document
  that relied on the looser reading; the fix is one key, `"required?": true`
  on the record's field wherever the record does promise the value.

## [0.1.0] 2026-09-06

The first release. StatifierDatamodel is the reader of a datamodel document
and the home of every question that can be answered from the document
alone: the path/type index over the three scopes, the named record and
shape declarations under the `types` key, the read check between two type
expressions, the projection to the expression language's value kinds, and
what a redefined declaration takes away. The package has no runtime
dependencies and none in the family, which is what lets statifier_blocks
and statifier_ui take it without either taking the other. The contract is
ADR-0001.

### Added

- A datamodel document indexes to its declared paths and their types, at
  every nesting depth, through one total admission step that tells "not a
  document" apart from "a document declaring nothing".
- The document-level reads over that index: the declared-path set, the
  declared paths strictly under a prefix in document order, and the `one_of`
  enumerations the document declares per path.

- The document's `types` key indexes to the named record and shape
  declarations it carries, by name, through one total function: a
  half-written declaration declares nothing, and a field typed by another
  declared name resolves to it.
- Type expressions over a document - a declared name, one of the closed
  set's types, an opaque string that compares by identity, or unknown -
  with the read check over them: unknown is permissive both ways, identity
  is satisfied, and a record is read as a shape when the record's fields
  cover the shape's required set. A record is never read as another record.

- `StatifierDatamodel.Index.path_types/1` projects an index to
  `%{path => kind | {:list, kind} | {:one_of, values}}` in the expression
  language's vocabulary of value kinds, which is the map an expression
  editor consumes. A path this projection cannot name - an object, a list
  whose element type the document does not give, a type outside the closed
  set - is absent from the map, and absence means unknown, not wrong.

- A redefined declaration reports what it takes away: every field removed,
  retyped, made required, added as required, or newly constrained by a
  `one_of` group, ordered by field name. Widening a declaration - an
  optional field added, a required field made optional, a group removed -
  reports nothing, and a name declared on neither side is an error rather
  than an empty list.
- The required field names of a shape that a map does not fill, in the
  shape's own field order. A name that is not a shape - a record, or a name
  the document does not declare - is an error rather than nothing missing.

### Changed

- `date` is admitted in the document's closed type set, so an entry typed
  `"date"` indexes as `:date` where it was previously an unknown type. A
  document already spelling `"date"` needs no change; a host that worked
  around the gap by spelling such a path `"datetime"` or `"string"` should
  spell it `"date"` now.
