import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../config/config.dart';
import '../../features/map/controller/kubus_map_controller.dart';

class MapCameraController {
  MapCameraController({
    required KubusMapController mapController,
    required bool Function() isReady,
  })  : _mapController = mapController,
        _isReady = isReady;

  final KubusMapController _mapController;
  final bool Function() _isReady;

  _QueuedCameraRequest? _queued;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _queued = null;
  }

  void flushQueuedIfReady() {
    if (_disposed) return;
    if (!_isReady()) return;

    final queued = _queued;
    if (queued == null) return;
    _queued = null;
    // Fire and forget; caller doesn't need to await.
    // ignore: discarded_futures
    animateTo(
      queued.target,
      zoom: queued.zoom,
      rotation: queued.rotation,
      tilt: queued.tilt,
      duration: queued.duration,
      compositionYOffsetPx: queued.compositionYOffsetPx,
      queueIfNotReady: false,
    );
  }

  Future<void> animateTo(
    LatLng target, {
    double? zoom,
    double? rotation,
    double? tilt,
    Duration duration = const Duration(milliseconds: 320),
    double compositionYOffsetPx = 0.0,
    bool queueIfNotReady = true,
  }) async {
    if (_disposed) return;

    if (!_isReady()) {
      if (queueIfNotReady) {
        _queued = _QueuedCameraRequest(
          target: target,
          zoom: zoom,
          rotation: rotation,
          tilt: tilt,
          duration: duration,
          compositionYOffsetPx: compositionYOffsetPx,
        );
      }
      return;
    }

    await _mapController.animateTo(
      target,
      zoom: zoom,
      rotation: rotation,
      tilt: tilt,
      duration: duration,
      compositionYOffsetPx:
          compositionYOffsetPx.abs() > 0.5 ? compositionYOffsetPx : null,
    );
  }

  /// Animates the camera into/out of isometric mode.
  ///
  /// Returns the zoom value that should be treated as the next logical zoom in
  /// the calling screen when [adjustZoomForScale] is enabled.
  Future<double> applyIsometricCamera({
    required bool enabled,
    required LatLng center,
    required double zoom,
    required double bearing,
    bool adjustZoomForScale = false,
    Duration duration = const Duration(milliseconds: 320),
    bool queueIfNotReady = true,
  }) async {
    final shouldEnable = enabled && AppConfig.isFeatureEnabled('mapIsometricView');
    final targetPitch = shouldEnable ? 54.736 : 0.0;
    final targetBearing =
        shouldEnable ? (bearing.abs() < 1.0 ? 18.0 : bearing) : 0.0;

    double targetZoom = zoom;
    if (adjustZoomForScale) {
      const scale = 1.2;
      final delta = math.log(scale) / math.ln2;
      targetZoom = shouldEnable ? (zoom + delta) : (zoom - delta);
      targetZoom = targetZoom.clamp(3.0, 24.0).toDouble();
    }

    await animateTo(
      center,
      zoom: targetZoom,
      rotation: targetBearing,
      tilt: targetPitch,
      duration: duration,
      queueIfNotReady: queueIfNotReady,
    );

    return targetZoom;
  }
}

class _QueuedCameraRequest {
  _QueuedCameraRequest({
    required this.target,
    required this.zoom,
    required this.rotation,
    required this.tilt,
    required this.duration,
    required this.compositionYOffsetPx,
  });

  final LatLng target;
  final double? zoom;
  final double? rotation;
  final double? tilt;
  final Duration duration;
  final double compositionYOffsetPx;
}
