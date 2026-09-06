defmodule StatifierDatamodel do
  @moduledoc """
  The datamodel document and what can be decided from it, with no dependency
  on the block editor, the compiler, or the UI.

  A datamodel document is a host's typed description of the data universe an
  author writes conditions against: three scopes - `global`, `local`,
  `event` - each carrying entries with a `name`, an absolute dotted `path`, a
  `type` and a `label`, plus a `types` key of named record and shape
  declarations. This package is the reader of that document and the home of
  every question that can be answered from the document alone:

    * the path/type index over an admitted document, and its projection to
      the declared-path set;
    * the declared types, and the read check - identity, then a record read
      as a shape is admitted when the record's fields cover the shape's
      required set;
    * compatibility of a redefined declaration against the one it replaces;
    * required-field coverage of a map against a shape;
    * the projection of the index to per-path value kinds an expression
      editor consumes.

  Every function is pure and total over an admitted document. What is not
  here, on purpose: the environment walk over a block document, which needs
  the block tree and stays in `statifier_blocks`; anything that renders,
  which is `statifier_ui`'s; and any runtime enforcement, which no record in
  the family has asked for. Both of those packages depend on this one, and
  this one depends on nothing in the family.

  The document shape and the index are re-homed here from `statifier_blocks`
  (its ADR-0006, accepted 2026-08-29), and ADR-0001 in this repository is the
  record of the re-homing: the same three scopes, the same closed scalar set
  plus `date`, the same declared-path projection, and the `types` key that
  the re-homing adds.

  This module is the package's root and holds no functions. The document
  and its index are `StatifierDatamodel.Index` and
  `StatifierDatamodel.Document`; the declared types, the read check,
  compatibility and coverage land beside them as the record's remaining
  decisions are built.
  """
end
