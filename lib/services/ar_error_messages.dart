import '../l10n/app_localizations.dart';

/// Translates AR platform codes into user-facing guidance.
///
/// Users never see `PlatformException`, `TrackingFailureReason`, or a raw
/// ARCore enum. Every code maps to a localized sentence that says what to do;
/// anything unrecognized falls back to a generic recoverable message rather
/// than leaking platform text.
class ArErrorMessages {
  const ArErrorMessages._();

  /// Guidance for a recoverable session error reported by the platform.
  ///
  /// Codes come from the native `onSessionError` channel call.
  static String forSessionError(AppLocalizations l10n, String code) {
    switch (code) {
      case 'camera_unavailable':
        return l10n.arErrorCameraUnavailable;
      case 'arcore_install_required':
        return l10n.arErrorArcoreInstallRequired;
      case 'arcore_install_declined':
        return l10n.arErrorArcoreInstallDeclined;
      case 'arcore_update_required':
        return l10n.arErrorArcoreUpdateRequired;
      case 'app_update_required':
        return l10n.arErrorAppUpdateRequired;
      case 'arcore_unsupported_device':
        return l10n.arErrorArcoreUnsupportedDevice;
      default:
        return l10n.arErrorSessionUnavailable;
    }
  }

  /// Whether a session error can be retried in place.
  ///
  /// An unsupported device cannot; everything else is worth another attempt
  /// once the user has acted.
  static bool isRetryable(String code) => code != 'arcore_unsupported_device';

  /// Guidance for an ARCore [TrackingFailureReason].
  ///
  /// Returns `null` when tracking is fine or the reason is `NONE`, so callers
  /// can hide the guidance area entirely rather than showing filler.
  static String? forTrackingFailure(
    AppLocalizations l10n,
    String? reason,
  ) {
    switch (reason) {
      case 'INSUFFICIENT_LIGHT':
        return l10n.arTrackingInsufficientLight;
      case 'EXCESSIVE_MOTION':
        return l10n.arTrackingExcessiveMotion;
      case 'INSUFFICIENT_FEATURES':
        return l10n.arTrackingInsufficientFeatures;
      case 'BAD_STATE':
      case 'CAMERA_UNAVAILABLE':
        return l10n.arTrackingBadState;
      case 'NONE':
      case null:
      case '':
        return null;
      default:
        // An unmapped reason is still a real tracking problem; give the
        // generic recovery hint instead of the raw enum name.
        return l10n.arTrackingInitializing;
    }
  }

  /// Guidance while the session is searching for its position.
  static String initializing(AppLocalizations l10n) =>
      l10n.arTrackingInitializing;
}
