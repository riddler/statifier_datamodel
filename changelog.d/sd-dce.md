### Added

- The document's `types` key indexes to the named record and shape
  declarations it carries, by name, through one total function: a
  half-written declaration declares nothing, and a field typed by another
  declared name resolves to it.
- Type expressions over a document - a declared name, one of the closed
  set's types, an opaque string that compares by identity, or unknown -
  with the read check over them: unknown is permissive both ways, identity
  is satisfied, and a record is read as a shape when the record's fields
  cover the shape's required set. A record is never read as another record.

### Changed

- `date` is admitted in the document's closed type set, so an entry typed
  `"date"` indexes as `:date` where it was previously an unknown type. A
  document already spelling `"date"` needs no change; a host that worked
  around the gap by spelling such a path `"datetime"` or `"string"` should
  spell it `"date"` now.
