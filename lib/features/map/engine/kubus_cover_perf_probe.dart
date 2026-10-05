import 'kubus_cover_perf_probe_stub.dart'
    if (dart.library.js_interop) 'kubus_cover_perf_probe_web.dart' as impl;

/// Phases of the close-level cover pipeline that are timed separately, so a
/// slow cover can be attributed to the network, the raster or the map.
enum KubusCoverPhase {
  /// Network download plus image decode (the loader's fetch).
  fetchDecode,

  /// Drawing the cover marker and reading the PNG back.
  renderPng,

  /// `addImage` on the map controller.
  addImage,

  /// From a coalesced resync request to the marker source rebuild starting.
  resyncDelay,
}

/// Records one cover-pipeline timing for the browser performance harness.
///
/// A no-op unless the page opted in (on web, `window.__kubusCoverPerf` is an
/// array set by `scripts/qa/product_v5_spatial_perf_ab.mjs`), so production
/// visitors pay nothing.
void recordKubusCoverPhase(KubusCoverPhase phase, Duration elapsed) =>
    impl.recordKubusCoverPhase(phase.name, elapsed.inMicroseconds / 1000.0);

/// Records a high-water mark (decoded cover count/bytes, registered images)
/// for the browser performance harness; a no-op unless the page opted in with
/// a `window.__kubusCoverGauges` object.
void recordKubusCoverGauge(String name, double value) =>
    impl.recordKubusCoverGauge(name, value);
