import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../services/backend_api_service.dart';

/// Composer copy for a failed publish.
///
/// Upload quota rejections name the wait. When [unuploadedMediaCount] is set,
/// the publish stopped on media, so the copy says how many files remain and
/// that the draft is kept. Anything else gets [fallback], or the mobile
/// generic failure toast when no fallback is given.
String communityComposerFailureMessage(
  AppLocalizations l10n,
  Object error, {
  int? unuploadedMediaCount,
  String? fallback,
}) {
  if (communityPostAlreadyCommitted(error)) {
    return l10n.communityComposerAlreadyCommitted;
  }
  if (error is BackendApiRequestException && error.statusCode == 429) {
    final seconds = error.retryAfter?.inSeconds;
    return seconds == null
        ? l10n.communityComposerRateLimitedGeneric
        : l10n.communityComposerRateLimitedSeconds(seconds < 1 ? 1 : seconds);
  }
  if (error is UploadRateLimitedException) {
    return communityUploadRateLimitMessage(l10n, error.retryAfter);
  }
  if (unuploadedMediaCount != null && unuploadedMediaCount > 0) {
    return l10n.communityComposerMediaUploadFailed(unuploadedMediaCount);
  }
  return fallback ?? l10n.communityComposerCreatePostFailedToast;
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

/// Only the committed ledger gap needs feed inspection. Other 409s remain errors.
bool communityPostAlreadyCommitted(Object error) {
  if (error is! BackendApiRequestException || error.statusCode != 409) {
    return false;
  }
  try {
    final payload = jsonDecode(error.body ?? '');
    return payload is Map &&
        payload['errorCode'] == 'COMMUNITY_POST_ALREADY_COMMITTED';
  } on FormatException {
    return false;
  }
}
