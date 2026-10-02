# Spatial runtime integration

The Flutter application treats spatial content as a versioned `kubus.spatial/1`
record. A record can describe Gaussian-splat or existing GLB/GLTF content and can
contain preview, mobile, and archive variants. Multiple records can belong to the
same artwork or marker, so the UI can present spatial history over time.

## Capture and privacy

Android capture uses the existing native ARCore session to return an RGB frame,
camera pose, intrinsics, timestamp, and depth/confidence only when the device and
ARCore session expose them. iOS uses the ARKit adapter for tracked placement and
capture metadata. Capability labels never claim depth when the platform did not
return it.

Raw frames are transferred only to a paired Kubus Node with a scoped local
credential. They are not sent to the public backend or public gateways. The
capture remains local unless the user explicitly requests publication of selected
processed variants. The app stores the local credential in secure storage and
never includes it in content URLs, analytics, or normal logs.

## Capture association

A capture is always filed under exactly one artwork, and optionally one marker.
The pair of ids is the durable authority; the record also stores display
snapshots of the artwork title, artist and marker label, used only so an offline
device can render a readable label. Snapshots never resolve, match, or relink a
record.

There is no fallback for a missing target. A capture cannot begin until the user
has named an artwork explicitly — by launching capture from an artwork or a
marker, or by choosing one in the picker. Once a capture has begun it owns its
target for its whole life: reordering the artwork provider, uploading a new
artwork, changing a selection elsewhere, or resuming after a restart cannot move
it onto different work.

Surfaces resolve each record through that record's own `artworkId` and
`markerId`. A reference that no longer resolves is reported as unavailable and
keeps its stored id, because silently relinking a capture destroys the only
evidence of what it was a scan of. Repointing a record is an explicit user
action, and is refused outright for a published record.

## Capture lifecycle

`SpatialLibraryRecord` is at schema version 3. Beyond the source and result, it
carries a user-chosen display name and note, the association snapshots, revision
lineage, a stale-result flag, and a persisted network compute request. Every
field added since v1 is optional with a safe default, so older records upgrade
in place and no capture is discarded.

- **Continue capture** reopens the record's own raw source, rebuilds coverage
  from the poses already on disk, and folds new samples back into the same
  record. Abandoning a continuation never deletes the source.
- **Stale results.** Samples added after a processed result leave that result on
  disk but mark it stale. A stale result is never presented as current and
  cannot be published; the capture has to be processed again.
- **Revisions.** A published archive is immutable. Adding to it branches a new
  private draft seeded with a copy of the parent's raw source, recording the
  parent record and the public version it came from. The parent keeps its
  archive, its result and its capture.

## Processing requests

Processing is chosen between two options that differ in kind, not degree: the
user's own paired Node, or a third party's GPU on the kubus network. Reaching
the user's own Node over remote HTTPS rather than the LAN changes the route, not
the trust, so it stays one option with a connection note. Only the network
option asks for privacy consent.

A network request is written to disk before anything is sent, and is offered
even when provider discovery currently returns nobody: discovery describes this
instant, not the capability. The persisted request advances through
`networkRequested` → `searchingProvider` → `providerOffered` →
`providerAccepted` → `queued` → `processing` → `verifying` → `downloading` →
`complete`, and can end in `failed`, `expired` or `cancelled`. Open requests are
resumed at launch, so closing the app never loses one. Provider details —
identity, tier, queue depth, estimates — are shown only when the protocol
reports them; nothing is estimated locally.

## Resolution order

On native platforms, `ipfs://` content is attempted through the paired node first,
then the configured IPFS/Kubus gateways, and finally the legacy backend fallback.
The local WebView viewer receives bytes through a loopback proxy so the credential
stays in an authorization header. Flutter Web deliberately skips insecure LAN
HTTP endpoints to avoid mixed-content and browser-origin regressions.

## Rendering boundary

`SpatialViewer` is renderer-neutral. Its bundled archive viewer currently uses
Spark 2.1.0 and Three.js 0.185.1 for orbit/zoom inspection, quality selection,
loading, poster, and failure states. This WebView is an archive viewer; it is not
placed transparently over the camera and is not presented as tracked AR.

Camera-aligned placement remains owned by `SpatialTrackingAdapter` and the native
ARCore/ARKit path. A future native splat renderer can implement that boundary
without changing domain records or publication APIs.

## Platform verification

Android is exercised by the repository Android build. The iOS ARKit dependency is
enabled with its current adapter, but an iOS native build still requires macOS and
Xcode and cannot be verified from the Windows development environment.
