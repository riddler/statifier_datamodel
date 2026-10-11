# Upgrading a host from 0.4 to 0.6

This page says what a host changes to move `statifier_datamodel` from
0.4.0 to 0.6.0, one minor at a time: 0.4 to 0.5, the 0.5.1 and 0.5.2
patches, then 0.5 to 0.6. A host here is the code that
embeds the package: the datamodel documents it writes, the calls it makes
to `StatifierDatamodel.Index`, `StatifierDatamodel.Document`,
`StatifierDatamodel.Declarations`, `StatifierDatamodel.Types`,
`StatifierDatamodel.Compatibility` and `StatifierDatamodel.Coverage`, and
any relation of its own it wraps around the read check. What each release
added is in [CHANGELOG.md](../CHANGELOG.md); this page lists only what a
host has to do about it, and says **NONE** where the answer is nothing.

Move the pin with each minor, as the README recommends:
`{:statifier_datamodel, "~> 0.6.0"}`. The Elixir requirement
(`~> 1.18`) is the same on every step of this page, and the package still
has no runtime dependencies. A host that takes this package through
`statifier_blocks` or `statifier_ui` need not move either of them with
it: statifier_blocks from 0.35.0 through 0.43.0 and statifier_ui from
0.10.1 through 0.11.0 each require `~> 0.4`, which admits 0.5 and 0.6.

## 0.4 to 0.5

Must change: **NONE**. 0.5.0 adds one module and one shipped file and
changes no existing signature or answer: `StatifierDatamodel.Index.index/1`
answers exactly as before for every document, and no module other than the
new one gains or loses a function.

May start doing:

- **Validate a document before you index it.** The package now ships a
  hand-written draft-07 JSON Schema of the version-1 datamodel document,
  `priv/schemas/datamodel-document.schema.json`, in the tarball a host
  fetches. `StatifierDatamodel.Schema.path/0` answers where it is
  installed and `StatifierDatamodel.Schema.json/0` answers its text (the
  text, not a decoded map). Hand it to the draft-07 validator your own
  language already has. The schema is advisory: nothing in the package
  calls it, and it is deliberately stricter than `index/1`, so a document
  the schema rejects still indexes as it always did. What it rejects is
  yours to read and to give a severity; the `StatifierDatamodel.Schema`
  documentation lists the kinds of slip it catches.

Worth knowing, with no change to make:

- **If you wrap `StatifierDatamodel.Types.satisfies/3` in a relation of
  your own**, the `StatifierDatamodel.Types` documentation now states the
  rule such a wrapper keeps: whenever `satisfies/3` answers not-satisfied,
  the wrapper answers not-satisfied too. It also says reasons in
  `t:StatifierDatamodel.Types.reason/0` may be added as records take
  decisions, so match the reasons you render and send anything else to a
  default clause. No reason was added or re-spelled in 0.5.0; this is
  documentation of what a wrapper may rely on, not a change to the check.

## 0.5.0 to 0.5.1

Must change: **NONE**. 0.5.1 is a documentation release: the code and the
shipped schema are unchanged from 0.5.0. `~> 0.5.0` already takes it.

## 0.5.1 to 0.5.2

Must change: **NONE**. 0.5.2 is a documentation release: the code and the
shipped schema are unchanged from 0.5.1. `~> 0.5.0` already takes it.

## 0.5 to 0.6

Must change: **NONE**. 0.6.0 adds one public function and changes no
existing signature: `StatifierDatamodel.Index.index/1` and
`StatifierDatamodel.Index.path_types/1` answer exactly as before for every
document.

May start doing:

- **Ask a type expression for its value kind.**
  `StatifierDatamodel.Types.value_kind/1` answers the expression
  language's value kind for a type expression: `:string`, `:number` for
  `:integer` and `:decimal`, and `:boolean`, `:date`, `:datetime` and
  `:duration` as themselves, with `nil` for `:object`, `:list` and every
  type that is not one of the nine. It is the answer `path_types/1` gives,
  which now reads its kinds from it.

Worth knowing, with no change to make:

- **If you validate documents against the shipped JSON Schema**, it now
  rejects a scope whose `label` or `description` is not a string, and a
  declaration whose `name` or `label` is not a string. The schema stays
  advisory, and `index/1` admits and answers for every document exactly as
  before.
