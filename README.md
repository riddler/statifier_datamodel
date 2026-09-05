# StatifierDatamodel

The datamodel document and what can be decided from it, with no dependency on
the block editor, the compiler, or the UI.

**Status: scaffold.** Nothing is implemented yet. The package skeleton is in
place; the contract is recorded in
[ADR-0001](https://github.com/riddler/statifier_datamodel/blob/main/docs/adr/0001-datamodel-document.md)
and the code lands behind it.

## The charter

A datamodel document is a host's typed description of the data universe an
author writes conditions against. It has three scopes - `global`, `local`,
`event` - each carrying entries with a `name`, an absolute dotted `path`, a
`type` and a `label`; and a `types` key of named record and shape
declarations, each with ordered `fields` carrying `name`, `type` and
`required?`. This package is the reader of that document and the home of every
question that can be answered from the document alone:

- **The index.** The path/type index over an admitted document, and its
  projection to the declared-path set: every entry contributes its own path
  at every nesting depth, and nothing else does.

- **Declared types and the read check.** A record type is a fact about what a
  write puts at a path; a shape is a constraint a read places on one. The
  read check is identity first, and then a record read as a shape is admitted
  when the record's fields cover the shape's required set.

- **Compatibility.** Whether a redefined declaration still satisfies every
  read that assumed the one it replaces - every way the new declaration
  narrows the old one, listed.

- **Coverage.** The required field names of a shape that a map does not fill,
  in declaration order.

- **Value kinds for an expression editor.** The projection of the index to
  per-path value kinds - a kind, a list of a kind, or an enumeration - which
  is what an expression editor consumes to offer the right operators and the
  right value control for a path.

Every function is pure and total over an admitted document. What is
deliberately not here: the environment walk over a block document, which needs
the block tree and stays in
[statifier_blocks](https://github.com/riddler/statifier_blocks); anything that
renders, which is [statifier_ui](https://github.com/riddler/statifier-ui)'s;
and any runtime enforcement. Both of those packages depend on this one, and
this one depends on nothing in the family.

The document shape and the index are re-homed here from statifier_blocks'
ADR-0006; this repository's ADR-0001 is the record of the re-homing.

## Installation

```elixir
def deps do
  [
    {:statifier_datamodel, "~> 0.1"}
  ]
end
```

Not yet published to Hex.

## License

MIT - see
[LICENSE](https://github.com/riddler/statifier_datamodel/blob/main/LICENSE).
