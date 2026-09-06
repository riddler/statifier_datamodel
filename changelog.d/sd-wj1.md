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
