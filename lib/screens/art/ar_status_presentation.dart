import 'package:flutter/foundation.dart';

import '../../features/spatial/spatial_status_presentation.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ar_error_messages.dart';

/// What the AR session is doing right now, as a case rather than a sentence.
enum ArStatusKind {
  /// The session is coming up.
  starting,

  /// Handing the camera between the scanner and the AR session.
  switchingCamera,

  /// Tracking is not established yet.
  findingSurface,

  /// Tracking is stable.
  tracking,

  /// A spatial capture is sampling.
  capturing,

  /// A spatial capture is suspended but intact.
  paused,

  /// The session reported an error.
  error,
}

/// The AR header status, split into a short pill label and the long guidance
/// that belongs on the guidance surface.
///
/// The pill used to render whole sentences — "Keep the artwork in view and
/// maintain overlap." — inside a rounded chip competing with three icon
/// buttons on a 360dp row, which clipped to nonsense on real hardware. A
/// status is one or two words; the explanation is a separate surface.
@immutable
class ArStatusPresentation {
  const ArStatusPresentation({
    required this.kind,
    required this.label,
    required this.tone,
    this.guidance,
  });

  final ArStatusKind kind;

  /// One or two words. Never a sentence, never an error message.
  final String label;

  final SpatialStatusTone tone;

  /// Long-form explanation for the guidance surface, when there is one.
  final String? guidance;

  /// Builds the status from the session facts the AR screen already tracks.
  ///
  /// [sessionErrorCode] wins over everything: an unusable session is the only
  /// thing worth saying.
  static ArStatusPresentation resolve(
    AppLocalizations l10n, {
    String? sessionErrorCode,
    bool isSwitchingCamera = false,
    bool isCapturing = false,
    bool isCapturePaused = false,
    bool isTracking = false,
  }) {
    if (sessionErrorCode != null) {
      return ArStatusPresentation(
        kind: ArStatusKind.error,
        label: l10n.arStatusError,
        tone: SpatialStatusTone.negative,
        // The full sentence goes to the guidance card, which has room for it.
        guidance: ArErrorMessages.forSessionError(l10n, sessionErrorCode),
      );
    }
    if (isCapturing) {
      return ArStatusPresentation(
        kind: ArStatusKind.capturing,
        label: l10n.arStatusCapturing,
        tone: SpatialStatusTone.captured,
      );
    }
    if (isCapturePaused) {
      return ArStatusPresentation(
        kind: ArStatusKind.paused,
        label: l10n.arStatusPaused,
        tone: SpatialStatusTone.pending,
      );
    }
    if (isSwitchingCamera) {
      return ArStatusPresentation(
        kind: ArStatusKind.switchingCamera,
        label: l10n.arStatusSwitching,
        tone: SpatialStatusTone.pending,
      );
    }
    if (isTracking) {
      return ArStatusPresentation(
        kind: ArStatusKind.tracking,
        label: l10n.arStatusTracking,
        tone: SpatialStatusTone.positive,
      );
    }
    return ArStatusPresentation(
      kind: ArStatusKind.findingSurface,
      label: l10n.arStatusFindingSurface,
      tone: SpatialStatusTone.pending,
    );
  }
}
