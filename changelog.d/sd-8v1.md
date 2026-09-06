### Added

- `StatifierDatamodel.Index.path_types/1` projects an index to
  `%{path => kind | {:list, kind} | {:one_of, values}}` in the expression
  language's vocabulary of value kinds, which is the map an expression
  editor consumes. A path this projection cannot name - an object, a list
  whose element type the document does not give, a type outside the closed
  set - is absent from the map, and absence means unknown, not wrong.
