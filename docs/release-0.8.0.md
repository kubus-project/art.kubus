# art.kubus 0.8.0 — Spatial memory

Art changes in place. A mural is repainted, an installation disappears, a
public space is rebuilt. art.kubus 0.8.0 adds a way to preserve those moments
as spatial records — created by the community, processed with kubus Node, and
published only when their author is ready.

Release 0.8.0 updates the frontend version to `0.8.0+26081201`.

## A new spatial archive

- Discover an artwork, create a spatial capture, review it, and choose where
  reconstruction happens: on a paired kubus Node or on an eligible network GPU.
- Keep reconstructed results unpublished while reviewing them. Publication is
  always an explicit choice and adds only the selected spatial variants to the
  canonical public art archive.
- Explore canonical captures through a focused 3D viewer with sensible quality
  selection, reset and fullscreen controls, retry states, and archival quality
  available on demand rather than downloaded automatically.
- Move through an artwork's spatial history as an art/archive timeline. Current
  and earlier captures remain connected to the artwork, its place, and its
  evolving context.
- Find spatial records from artwork details and subtle map indicators without
  turning the map into a technical interface.

## Your GPU when you have one. The Kubus network when you don't.

- Pair the app with kubus Node by QR code and see clear joining, contributing,
  degraded, and locked participation states in English and Slovenian.
- Prefer local processing for maximum privacy, or let the network choose an
  eligible provider automatically. Advanced users can select a node using
  practical GPU, VRAM, queue, and reliability information.
- Follow real processing stages from preparation and encryption through GPU
  work, result transfer, verification, and review. Failure states explain what
  happened, where the source capture remains, and which recovery actions are
  available.
- Archive contribution remains mandatory for node participation; sharing spare
  GPU is optional. Archive and compute contribution records remain separate.

## Privacy, stated precisely

- Raw captures remain local to the paired node by default and are not added to
  the public object registry or public archive pin set.
- Network-compute input is encrypted before content-addressed transport.
- The selected compute provider temporarily decrypts and sees the source data
  while processing. For maximum privacy, process locally.
- A processed result in ordinary local Kubo storage is unpublished and unlisted,
  but knowledge of its CID is not a cryptographic privacy boundary.
- Publishing makes the selected spatial bundle public, canonical, and eligible
  for replication by participating nodes. The raw source capture is not
  published with it.

## Integrity and reliability

- kubus Node spatial processing becomes available only after genuine public
  archive participation has been verified; an accepted heartbeat alone cannot
  unlock useful processing.
- Remote compute completion uses verified provider evidence, requester
  acknowledgement, output identity, and retrievability checks before a compute
  contribution can be recorded.
- Marker publication now rejects successful-looking responses without a
  canonical marker identity, and account-scoped first-contribution telemetry
  cannot be suppressed by another user of the same installation.
- Browser-safe spatial retrieval preserves public HTTPS resolution on the web,
  while native clients can prefer a paired local node.

## Validation

Promotion to `dev` requires the repository's complete protected matrix:
Flutter analysis and tests, release web build and browser smoke, unsigned
Android and iOS release compilation, backend compatibility, routing,
documentation, provenance, and security checks. The immutable `v0.8.0` mobile
release is created only from the production branch after the documented
`dev`-to-`master` promotion.
