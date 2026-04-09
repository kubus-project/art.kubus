import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';

const int authMethodsPanelUsernameMinLength = 3;
const int authMethodsPanelUsernameMaxLength = 50;

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
  final username = rawUsername.trim();
  if (username.isEmpty) {
    return required ? l10n.profileEditUsernameRequiredError : null;
  }
  if (username.length < authMethodsPanelUsernameMinLength) {
    return l10n.profileEditUsernameMinLengthError;
  }
  if (username.length > authMethodsPanelUsernameMaxLength) {
    return l10n.profileEditUsernameMaxLengthError;
  }
  return null;
}
