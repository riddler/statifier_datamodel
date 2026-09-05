# Architecture Decision Records

| # | Decision | Status |
|---|---|---|
| [0001](0001-datamodel-document.md) | The datamodel document, re-homed: a typed three-scope declaration with named record and shape types, and the declared-path set as its projection | proposed |

New ADRs: next number, same three-section format (Context, Decision,
Consequences), plus the typespecs and worked-example sections this family's
records carry. Pick the number against a freshly fetched remote.

This repository inherits the family's ADR practice rather than restating it,
so there is no local "record architecture decisions" record. A bare
`ADR-NNNN` cites this repository's own records; a cross-repo citation carries
the owning repo's beads prefix - `sd-ADR-0001` is how another repo cites this
repository's ADR-0001, `sb-ADR-0006` is statifier_blocks' ADR-0006, and
`st-ADR-0052` is statifier-ex's. Records in sibling repos that are still
being drafted are cited by bead id until their number is assigned.

A `## Note` on a record carries no Status line. Every Status line in these
records sits on the record's own header or under a `## Amendment`, because an
amendment changes what the record decides and a note does not: a note records
where something already decided renders, or what a sentence already accepted
was about.
