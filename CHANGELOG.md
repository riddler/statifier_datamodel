# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Entries for unreleased work are not written here directly. Each issue drops a
fragment in [`changelog.d/`](changelog.d/README.md); the fragments are assembled
into a version section at release. See that README for the format and for when a
change warrants an entry at all.

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
