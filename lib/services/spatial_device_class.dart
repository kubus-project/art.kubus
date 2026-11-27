import 'package:flutter/foundation.dart';

import 'spatial_device_class_io.dart'
    if (dart.library.js_interop) 'spatial_device_class_web.dart' as probe;

/// What the platform says about the device a spatial model is shown on.
///
/// Every field is optional: a missing signal never makes a device look
/// constrained by itself.
@immutable
class SpatialDeviceSignals {
  const SpatialDeviceSignals({
    this.nativeMobile = false,
    this.coarsePointer = false,
    this.viewportWidth,
    this.deviceMemoryGb,
  });

  /// A native Android or iOS build.
  final bool nativeMobile;

  /// Web only: the primary pointer is coarse (touch).
  final bool coarsePointer;

  /// Web only: the viewport width in CSS pixels.
  final double? viewportWidth;

  /// Web only: `navigator.deviceMemory` in GiB, when the browser exposes it.
  final double? deviceMemoryGb;
}

/// The single device-class decision for spatial delivery. The web viewer, the
/// native viewer and the artist review screen all read it, so the heuristic
/// exists exactly once: constrained devices open the small preview first and
/// ask before downloading a large optimised model.
class SpatialDeviceClass {
  const SpatialDeviceClass._();

  /// Viewports narrower than this are treated as phones.
  static const double compactWidth = 840;

  /// `navigator.deviceMemory` values up to this many GiB are low-memory.
  static const double lowMemoryGb = 4;

  static bool isConstrained(SpatialDeviceSignals signals) {
    final width = signals.viewportWidth;
    final memory = signals.deviceMemoryGb;
    return signals.nativeMobile ||
        signals.coarsePointer ||
        (width != null && width > 0 && width < compactWidth) ||
        (memory != null && memory > 0 && memory <= lowMemoryGb);
  }

  /// Replaces the platform probe in tests.
  @visibleForTesting
  static SpatialDeviceSignals? debugSignals;

  /// The signals of this device right now.
  static SpatialDeviceSignals get signals =>
      debugSignals ?? probe.readSpatialDeviceSignals();

  /// Whether this device is constrained right now.
  static bool get constrained => isConstrained(signals);
}
