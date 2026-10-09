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
  final rejection = communityValidationDetail(error);
  if (rejection != null) {
    return l10n.communityComposerValidationRejected(rejection);
  }
  return fallback ?? l10n.communityComposerCreatePostFailedToast;
}

/// Feedback for a picker result that did not fully fit, or null when every
/// picked file was added. Web pickers cannot cap the selection, so the
/// composer drops the overflow and says so.
String? communityComposerTrimmedMessage(
  AppLocalizations l10n, {
  required int added,
  required int picked,
  required int max,
}) {
  if (added >= picked) return null;
  return l10n.communityComposerMediaTrimmed(added, picked, max);
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

/// What the server said was wrong with a rejected post, from a 400 response.
///
/// Reads the express-validator `details` list (`field` and `message`), falling
/// back to a plain `error` string. Returns null for anything that is not a
/// validation rejection, so unrelated failures keep their own copy.
String? communityValidationDetail(Object error) {
  if (error is! BackendApiRequestException || error.statusCode != 400) {
    return null;
  }
  final Object? payload;
  try {
    payload = jsonDecode(error.body ?? '');
  } on FormatException {
    return null;
  }
  if (payload is! Map) return null;

  final messages = <String>[];
  final details = payload['details'];
  if (details is List) {
    for (final entry in details) {
      if (entry is! Map) continue;
      final message = entry['message'];
      if (message is! String || message.trim().isEmpty) continue;
      if (!messages.contains(message.trim())) messages.add(message.trim());
    }
  }
  if (messages.isEmpty) {
    final summary = payload['error'];
    if (summary is String &&
        summary.trim().isNotEmpty &&
        summary.trim() != 'Validation failed') {
      messages.add(summary.trim());
    }
  }
  if (messages.isEmpty) return null;
  return messages.take(3).join('; ');
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
