# Institution disciplines: review-only contract proposal

Institution `kind` identifies the venue type; it must not carry art or
collection disciplines. The current institution schema has no equivalent
field, so this work does not invent client values or deploy a migration.

A minimal additive design is an `institution_disciplines` relation keyed by
`(institution_id, discipline_code)`, with a controlled discipline vocabulary,
source URL, verification timestamp and reviewer identity. Public reads must
inherit the institution visibility predicate and return only approved
disciplines as an additive `disciplines` array; absent data remains an empty
array. Imported assertions remain pending until separately reviewed, and
verified participant-managed entries take precedence over imported proposals.
Source/licence evidence and rollback must accompany the operational import.

Before implementation, agree on vocabulary, multilingual labels, review and
ownership rules, and whether an existing taxonomy can be reused. Then prepare
an additive migration and both schema snapshots, a visibility-gated backend read,
Flutter parsing/display, database/API/widget tests, a rollback and an explicit
production approval. This document is not a schema migration or authorization
to write production data.
