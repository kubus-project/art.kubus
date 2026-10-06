import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Tells a caller that the map camera has *arrived* at a place.
///
/// Issuing a camera animation is not arrival: the map plugin resolves
/// `animateCamera` when the animation starts, and the map reports idle for
/// movement that precedes the flight (a resize, the first frame). A caller that
/// acts on arrival, such as selecting a deep-linked marker whose selection the
/// user-gesture rules would otherwise dismiss, waits on this instead.
///
/// It is event driven and uses no timers: a waiter completes on the first idle
/// that finds the camera at its target. A newer waiter supersedes an older one
/// (the older one completes so its caller can notice it is stale), and
/// [release] completes every waiter.
class KubusCameraArrivalTracker {
  final List<_Waiter> _waiters = <_Waiter>[];

  /// Whether a waiter is currently pending (debug and tests).
  @visibleForTesting
  int get pendingCount => _waiters.length;

  /// Whether a camera at [center] and [zoom] is at [target] and [targetZoom]:
  /// zoom within 0.02 and the centre within three screen pixels per axis.
  static bool isAt({
    required LatLng center,
    required double zoom,
    required LatLng target,
    required double targetZoom,
  }) {
    if (!zoom.isFinite || (zoom - targetZoom).abs() > 0.02) return false;
    final degreesPerPixel = 360.0 / (256.0 * math.pow(2.0, zoom));
    // A degree of longitude shrinks with latitude, a degree of latitude does
    // not shrink in the same way in the projection used for the tolerance.
    final latitudeScale =
        math.cos(target.latitude * math.pi / 180.0).abs().clamp(0.05, 1.0);
    final lngTolerance = degreesPerPixel * 3.0;
    final latTolerance = degreesPerPixel * latitudeScale * 3.0;
    return (center.latitude - target.latitude).abs() <= latTolerance &&
        (center.longitude - target.longitude).abs() <= lngTolerance;
  }

  /// Completes when the camera is idle at [target] and [zoom].
  ///
  /// [settled] says the camera is currently at rest (a camera frame has been
  /// seen and no movement is under way): if it is also at the target there is
  /// nothing to wait for.
  Future<void> wait({
    required LatLng center,
    required double currentZoom,
    required bool settled,
    required LatLng target,
    required double zoom,
  }) {
    release();
    if (settled &&
        isAt(
          center: center,
          zoom: currentZoom,
          target: target,
          targetZoom: zoom,
        )) {
      return Future<void>.value();
    }
    final waiter = _Waiter(target, zoom);
    _waiters.add(waiter);
    return waiter.completer.future;
  }

  /// The camera went idle at [center] and [zoom].
  void cameraIdle({required LatLng center, required double zoom}) {
    if (_waiters.isEmpty) return;
    final arrived = _waiters
        .where(
          (waiter) => isAt(
            center: center,
            zoom: zoom,
            target: waiter.target,
            targetZoom: waiter.zoom,
          ),
        )
        .toList(growable: false);
    for (final waiter in arrived) {
      _waiters.remove(waiter);
      if (!waiter.completer.isCompleted) waiter.completer.complete();
    }
  }

  /// Completes every pending waiter (superseded, or the owner is going away).
  void release() {
    if (_waiters.isEmpty) return;
    final released = List<_Waiter>.of(_waiters);
    _waiters.clear();
    for (final waiter in released) {
      if (!waiter.completer.isCompleted) waiter.completer.complete();
    }
  }
}

class _Waiter {
  _Waiter(this.target, this.zoom);

  final LatLng target;
  final double zoom;
  final Completer<void> completer = Completer<void>();
}
