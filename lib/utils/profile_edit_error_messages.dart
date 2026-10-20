import '../l10n/app_localizations.dart';
import '../providers/profile_provider.dart';

/// Maps a backend error code (or HTTP status) from a profile save or avatar
/// upload to a specific localized message. Returns null when no specific
/// message applies, so callers keep their generic fallback.
String? profileEditErrorMessageForCode(
  AppLocalizations l10n, {
  String? errorCode,
  int? statusCode,
}) {
  switch ((errorCode ?? '').trim().toUpperCase()) {
    case 'WALLET_SIGNATURE_REQUIRED':
    case 'AUTH_REQUIRED':
    case 'UNAUTHORIZED':
    case 'INVALID_TOKEN':
    case 'TOKEN_EXPIRED':
      return l10n.profileEditErrorSignInAgainToast;
    case 'PROFILE_OWNERSHIP_MISMATCH':
      return l10n.profileEditErrorOwnershipMismatchToast;
    case 'FILE_TOO_LARGE':
    case 'PAYLOAD_TOO_LARGE':
      return l10n.profileEditAvatarErrorTooLargeToast;
    case 'UNSUPPORTED_FILE_TYPE':
    case 'INVALID_FILE_TYPE':
    case 'UNSUPPORTED_MEDIA_TYPE':
      return l10n.profileEditAvatarErrorUnsupportedTypeToast;
    case 'RATE_LIMITED':
      return l10n.profileEditAvatarErrorRateLimitedToast;
  }
  switch (statusCode) {
    case 401:
      return l10n.profileEditErrorSignInAgainToast;
    case 413:
      return l10n.profileEditAvatarErrorTooLargeToast;
    case 415:
      return l10n.profileEditAvatarErrorUnsupportedTypeToast;
    case 429:
      return l10n.profileEditAvatarErrorRateLimitedToast;
  }
  return null;
}

/// Message for a failed avatar upload; falls back to the generic avatar toast.
String profileEditAvatarUploadErrorMessage(
  AppLocalizations l10n,
  ProfileRequestFailure? failure,
) {
  return profileEditErrorMessageForCode(
        l10n,
        errorCode: failure?.errorCode,
        statusCode: failure?.statusCode,
      ) ??
      l10n.profileEditAvatarUploadFailedToast;
}

/// Message for a failed profile save; falls back to the generic error toast.
String profileEditSaveErrorMessage(
  AppLocalizations l10n,
  ProfileRequestFailure? failure,
) {
  return profileEditErrorMessageForCode(
        l10n,
        errorCode: failure?.errorCode,
        statusCode: failure?.statusCode,
      ) ??
      l10n.profileEditErrorToast;
}
