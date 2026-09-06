### Changed

- A break from `Compatibility.breaks/2` documents its first element as the
  *kind*: the row of the redefinition table the break came from. The five
  kinds are unchanged and the vocabulary is closed at them, so a `case` over
  `:field_removed`, `:type_changed`, `:made_required`, `:required_added` and
  `:made_optional` is exhaustive and a host need not re-derive from the two
  declarations why a row broke. No result changes shape or value.
