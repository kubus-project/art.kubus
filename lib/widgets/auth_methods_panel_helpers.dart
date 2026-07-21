import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/username_policy.dart';
import 'package:art_kubus/utils/username_policy_messages.dart';

/// Onboarding length bounds are the canonical [UsernamePolicy] bounds; they are
/// re-exported under the historical names so existing callers keep compiling.
const int authMethodsPanelUsernameMinLength = UsernamePolicy.minLength;
const int authMethodsPanelUsernameMaxLength = UsernamePolicy.maxLength;

Map<String, dynamic>? decodeAuthMethodsPanelErrorPayload(Object error) {
  Map<String, dynamic>? tryDecode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      final jsonStart = trimmed.indexOf('{');
      if (jsonStart < 0) return null;
      try {
        final decoded = jsonDecode(trimmed.substring(jsonStart));
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }
  }

  if (error is BackendApiRequestException) {
    final decoded = tryDecode((error.body ?? '').toString());
    if (decoded != null) return decoded;
  }
  return tryDecode(error.toString());
}

bool isAuthMethodsPanelUsernameTakenConflict(Object error) {
  try {
    final bodyMap = decodeAuthMethodsPanelErrorPayload(error);
    final errorCode =
        (bodyMap?['errorCode'] ?? bodyMap?['code'] ?? '').toString().trim();
    if (errorCode.toUpperCase() == 'USERNAME_ALREADY_TAKEN') {
      return true;
    }
    final rawError = (bodyMap?['error'] ?? '').toString().toLowerCase();
    return rawError.contains('username') &&
        (rawError.contains('taken') || rawError.contains('exists'));
  } catch (_) {
    return false;
  }
}

bool isAuthMethodsPanelDuplicateEmailConflict(Object error) {
  if (error is BackendApiRequestException && error.statusCode != 409) {
    return false;
  }

  final bodyMap = decodeAuthMethodsPanelErrorPayload(error);
  final rawError = (bodyMap?['error'] ?? bodyMap?['message'] ?? '')
      .toString()
      .toLowerCase();
  if (rawError.contains('username') &&
      (rawError.contains('taken') || rawError.contains('exists'))) {
    return false;
  }
  if (rawError.contains('user already exists') ||
      rawError.contains('account already has an email') ||
      rawError.contains('login instead') ||
      rawError.contains('sign in instead')) {
    return true;
  }

  final fallbackMessage = error.toString().toLowerCase();
  return fallbackMessage.contains('user already exists') ||
      fallbackMessage.contains('account already has an email') ||
      fallbackMessage.contains('login instead') ||
      fallbackMessage.contains('sign in instead');
}

String? validateAuthMethodsPanelUsername(
  AppLocalizations l10n,
  String rawUsername, {
  required bool required,
}) {
  final rejection = UsernamePolicy.rejectionFor(rawUsername);
  // Onboarding may leave the username blank; every other rule is the canonical
  // policy shared with profile edit and handle presentation.
  if (rejection == UsernameRejection.empty && !required) return null;
  return usernameRejectionMessage(l10n, rejection);
}
