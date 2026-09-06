### Added

- A redefined declaration reports what it takes away: every field removed,
  retyped, made required, added as required, or newly constrained by a
  `one_of` group, ordered by field name. Widening a declaration - an
  optional field added, a required field made optional, a group removed -
  reports nothing, and a name declared on neither side is an error rather
  than an empty list.
- The required field names of a shape that a map does not fill, in the
  shape's own field order. A name that is not a shape - a record, or a name
  the document does not declare - is an error rather than nothing missing.
