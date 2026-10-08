import '../l10n/app_localizations.dart';
import '../services/backend_api_service.dart';

/// Composer copy for a failed publish. Upload quota rejections name the wait;
/// anything else keeps the generic failure toast.
String communityComposerFailureMessage(AppLocalizations l10n, Object error) {
  if (error is UploadRateLimitedException) {
    return communityUploadRateLimitMessage(l10n, error.retryAfter);
  }
  return l10n.communityComposerCreatePostFailedToast;
}

/// Seconds below this threshold are shown exactly; longer waits round to minutes.
const int _secondsDisplayCeiling = 90;

/// Names the server's upload wait, or gives a neutral retry hint when the
/// server did not say how long to wait.
String communityUploadRateLimitMessage(
  AppLocalizations l10n,
  Duration? retryAfter,
) {
  if (retryAfter == null) return l10n.communityUploadRateLimitedGeneric;
  final seconds = retryAfter.inSeconds;
  if (seconds < _secondsDisplayCeiling) {
    return l10n.communityUploadRateLimitedSeconds(seconds < 1 ? 1 : seconds);
  }
  return l10n.communityUploadRateLimitedMinutes((seconds / 60).ceil());
}
