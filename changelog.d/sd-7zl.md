### Changed

- The read check is stricter: a record field the document declares optional
  no longer covers a shape field the document marks required, so a read that
  was satisfied now answers `{:missing, [name]}`. Breaking for a document
  that relied on the looser reading; the fix is one key, `"required?": true`
  on the record's field wherever the record does promise the value.
