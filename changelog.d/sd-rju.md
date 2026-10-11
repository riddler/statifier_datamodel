### Added

- `StatifierDatamodel.Types.value_kind/1` answers the expression language's value kind for a type expression: `:string`, `:number` for `:integer` and `:decimal`, and `:boolean`, `:date`, `:datetime` and `:duration` as themselves, with `nil` for `:object`, `:list` and every type that is not one of the nine. It is the answer `StatifierDatamodel.Index.path_types/1` gives, which now reads its kinds from it and answers exactly as before.
