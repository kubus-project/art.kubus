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
