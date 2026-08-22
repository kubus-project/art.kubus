import 'spatial_tracking_adapter.dart';

/// Applies AR workload policy after the camera owner has switched modes.
///
/// Archive/View keeps the platform view mounted but pauses ARCore camera and
/// rendering work. Returning to Place or Spatial resumes the same session.
class ArModeSessionController {
  const ArModeSessionController();

  Future<void> apply(
    String mode,
    SpatialTrackingAdapter tracking,
  ) =>
      mode == 'view' ? tracking.pauseSession() : tracking.resumeSession();
}
