### Fixed

- `Events.from_document/1`, `Events.unresolved/1`, `Events.fetch/3` and `Reads.undeclared/2` no longer raise on an improper list in any list position they read: one is read as a value that is not a list, so it declares nothing, a read whose `path` is one is not a read, and a read whose `events` is one names no event.
