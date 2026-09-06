### Added

- A type expression admits an inline, unnamed shape, `{:shape, members}`, so a
  consumer holding a structural value the host never declared can say what it
  holds without inventing a declaration. The read check decides it against a
  declaration and against another inline shape member-wise, and `to_string/1`
  renders it.

### Changed

- Identity in the read check is member-set-wise for an inline shape: two
  inline shapes carrying the same members in a different order are the same
  type expression. Every other arm still compares by term, no document
  spelling changes, and a document that declares only named types reads
  exactly as it did.
