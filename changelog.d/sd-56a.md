### Added

- A datamodel document indexes to its declared paths and their types, at
  every nesting depth, through one total admission step that tells "not a
  document" apart from "a document declaring nothing".
- The document-level reads over that index: the declared-path set, the
  declared paths strictly under a prefix in document order, and the `one_of`
  enumerations the document declares per path.
