import 'dart:convert';

import 'backend_api_service.dart';

enum PasskeyErrorCode {
  duplicateCredential,
  cancelled,
  originIssue,
  malformedOptions,
  challengeExpired,
  credentialNotFound,
  verificationFailed,
  sharedChallengeStoreUnavailable,
  unavailable,
  unknown,
}

class PasskeyAppException implements Exception {
  const PasskeyAppException(this.code, this.message, {this.cause});

  final PasskeyErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

Never throwPasskeyError(PasskeyErrorCode code, String message,
    {Object? cause}) {
  throw PasskeyAppException(code, message, cause: cause);
}

PasskeyAppException mapWebAuthnException(
  Object? error, {
  String? name,
}) {
  final normalizedName = (name ?? _extractErrorName(error)).trim();
  switch (normalizedName) {
    case 'InvalidStateError':
      return PasskeyAppException(
        PasskeyErrorCode.duplicateCredential,
        'This passkey is already registered for this account. Try a different device or remove the existing passkey first.',
        cause: error,
      );
    case 'NotAllowedError':
      return PasskeyAppException(
        PasskeyErrorCode.cancelled,
        'Passkey approval was cancelled, blocked, or timed out. Retry and complete the browser prompt.',
        cause: error,
      );
    case 'SecurityError':
      return PasskeyAppException(
        PasskeyErrorCode.originIssue,
        'This browser origin is not allowed for art.kubus passkeys. Open the official app URL and try again.',
        cause: error,
      );
  }

  final text = (error ?? '').toString();
  if (text.contains('InvalidStateError')) {
    return mapWebAuthnException(error, name: 'InvalidStateError');
  }
  if (text.contains('NotAllowedError')) {
    return mapWebAuthnException(error, name: 'NotAllowedError');
  }
  if (text.contains('SecurityError')) {
    return mapWebAuthnException(error, name: 'SecurityError');
  }

  return PasskeyAppException(
    PasskeyErrorCode.unknown,
    'Passkey ceremony failed. Retry, or use email, Google, or wallet sign-in.',
    cause: error,
  );
}

PasskeyAppException passkeyCancelledException() {
  return const PasskeyAppException(
    PasskeyErrorCode.cancelled,
    'Passkey approval was cancelled. Retry and complete the browser prompt.',
  );
}

PasskeyAppException malformedPasskeyOptionsException(String detail) {
  return PasskeyAppException(
    PasskeyErrorCode.malformedOptions,
    'The server returned malformed passkey options: $detail.',
  );
}

PasskeyAppException mapBackendPasskeyException(Object error) {
  if (error is! BackendApiRequestException) {
    return error is PasskeyAppException
        ? error
        : PasskeyAppException(
            PasskeyErrorCode.unknown,
            'Passkey request failed. Retry, or use another sign-in method.',
            cause: error,
          );
  }

  final code = _backendErrorCode(error).toUpperCase();
  switch (code) {
    case 'PASSKEY_DUPLICATE_CREDENTIAL':
    case 'DUPLICATE_CREDENTIAL':
      return PasskeyAppException(
        PasskeyErrorCode.duplicateCredential,
        'This passkey is already registered. Use the existing passkey or remove it before adding it again.',
        cause: error,
      );
    case 'PASSKEY_CHALLENGE_EXPIRED':
    case 'CHALLENGE_EXPIRED':
      return PasskeyAppException(
        PasskeyErrorCode.challengeExpired,
        'The passkey prompt expired. Start again to get a fresh challenge.',
        cause: error,
      );
    case 'PASSKEY_ORIGIN_MISMATCH':
    case 'ORIGIN_MISMATCH':
      return PasskeyAppException(
        PasskeyErrorCode.originIssue,
        'This app URL is not allowed for passkeys. Open the official art.kubus app URL and retry.',
        cause: error,
      );
    case 'PASSKEY_CREDENTIAL_NOT_FOUND':
    case 'CREDENTIAL_NOT_FOUND':
      return PasskeyAppException(
        PasskeyErrorCode.credentialNotFound,
        'This passkey is not registered for the account. Try another passkey or sign in another way.',
        cause: error,
      );
    case 'PASSKEY_VERIFICATION_FAILED':
    case 'VERIFICATION_FAILED':
      return PasskeyAppException(
        PasskeyErrorCode.verificationFailed,
        'The passkey response could not be verified. Retry from the same browser and app URL.',
        cause: error,
      );
    case 'PASSKEY_CHALLENGE_STORE_UNAVAILABLE':
    case 'CHALLENGE_SHARED_STORE_UNAVAILABLE':
      return PasskeyAppException(
        PasskeyErrorCode.sharedChallengeStoreUnavailable,
        'Passkey sign-in is temporarily unavailable because challenge storage is not ready. Try again shortly.',
        cause: error,
      );
  }

  return PasskeyAppException(
    PasskeyErrorCode.unknown,
    _backendErrorMessage(error) ??
        'Passkey request failed. Retry, or use another sign-in method.',
    cause: error,
  );
}

String passkeyUserMessage(Object error) {
  if (error is PasskeyAppException) return error.message;
  return mapBackendPasskeyException(error).message;
}

void validatePasskeyCreationOptions(Map<String, dynamic> json) {
  _requireBase64UrlString(json['challenge'], 'challenge');
  final rp = _requireMap(json['rp'], 'rp');
  _requireNonEmptyString(rp['name'], 'rp.name');
  final rpId = (rp['id'] ?? '').toString().trim();
  if (rpId.contains('://')) {
    throw malformedPasskeyOptionsException('rp.id must be a domain, not a URL');
  }

  final user = _requireMap(json['user'], 'user');
  _requireNonEmptyString(user['name'], 'user.name');
  _requireNonEmptyString(user['displayName'], 'user.displayName');
  _requireBase64UrlString(user['id'], 'user.id');

  final params = json['pubKeyCredParams'];
  if (params is! List || params.isEmpty) {
    throw malformedPasskeyOptionsException(
        'pubKeyCredParams must be a non-empty list');
  }
  for (final item in params) {
    final param = _requireMap(item, 'pubKeyCredParams[]');
    _requireNonEmptyString(param['type'], 'pubKeyCredParams[].type');
    if (param['alg'] is! num) {
      throw malformedPasskeyOptionsException(
          'pubKeyCredParams[].alg must be numeric');
    }
  }

  _validateCredentialDescriptors(json['excludeCredentials'],
      field: 'excludeCredentials');
  _validateExtensions(json['extensions']);
}

void validatePasskeyRequestOptions(Map<String, dynamic> json) {
  _requireBase64UrlString(json['challenge'], 'challenge');
  final rpId = (json['rpId'] ?? json['rpID'] ?? '').toString().trim();
  if (rpId.isEmpty || rpId.contains('://')) {
    throw malformedPasskeyOptionsException('rpId must be a non-empty domain');
  }
  _validateCredentialDescriptors(json['allowCredentials'],
      field: 'allowCredentials');
  _validateExtensions(json['extensions'], byCredential: true);
}

String _extractErrorName(Object? error) {
  final text = (error ?? '').toString();
  final match = RegExp(r'\b([A-Za-z]+Error)\b').firstMatch(text);
  return match?.group(1) ?? '';
}

String _backendErrorCode(BackendApiRequestException error) {
  try {
    final parsed = jsonDecode((error.body ?? '').toString());
    if (parsed is Map) {
      return (parsed['errorCode'] ?? parsed['code'] ?? '').toString().trim();
    }
  } catch (_) {}
  return '';
}

String? _backendErrorMessage(BackendApiRequestException error) {
  try {
    final parsed = jsonDecode((error.body ?? '').toString());
    if (parsed is Map) {
      final value = (parsed['error'] ?? parsed['message'] ?? '').toString();
      return value.trim().isEmpty ? null : value.trim();
    }
  } catch (_) {}
  return null;
}

Map<String, dynamic> _requireMap(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw malformedPasskeyOptionsException('$field must be an object');
}

void _requireNonEmptyString(Object? value, String field) {
  if ((value ?? '').toString().trim().isNotEmpty) return;
  throw malformedPasskeyOptionsException('$field is required');
}

void _requireBase64UrlString(Object? value, String field) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) {
    throw malformedPasskeyOptionsException('$field is required');
  }
  if (!RegExp(r'^[A-Za-z0-9_-]+={0,2}$').hasMatch(text)) {
    throw malformedPasskeyOptionsException('$field must be base64url');
  }
  try {
    base64Url.decode(base64Url.normalize(text));
  } catch (_) {
    throw malformedPasskeyOptionsException('$field must be base64url');
  }
}

void _validateCredentialDescriptors(Object? value, {required String field}) {
  if (value == null) return;
  if (value is! List) {
    throw malformedPasskeyOptionsException('$field must be a list');
  }
  for (final item in value) {
    final descriptor = _requireMap(item, '$field[]');
    _requireNonEmptyString(descriptor['type'], '$field[].type');
    _requireBase64UrlString(descriptor['id'], '$field[].id');
  }
}

void _validateExtensions(Object? value, {bool byCredential = false}) {
  if (value == null) return;
  if (value is! Map) {
    throw malformedPasskeyOptionsException('extensions must be an object');
  }
  final extensions = Map<String, dynamic>.from(value);
  final prf = extensions['prf'];
  if (prf == null) return;
  final prfMap = _requireMap(prf, 'extensions.prf');
  final eval = prfMap['eval'];
  if (eval != null) {
    final evalMap = _requireMap(eval, 'extensions.prf.eval');
    _requireBase64UrlString(evalMap['first'], 'extensions.prf.eval.first');
  }
  final evalByCredential = prfMap['evalByCredential'];
  if (evalByCredential != null) {
    if (!byCredential) {
      throw malformedPasskeyOptionsException(
          'extensions.prf.evalByCredential is only valid for assertions');
    }
    final map = _requireMap(
      evalByCredential,
      'extensions.prf.evalByCredential',
    );
    for (final entry in map.entries) {
      final evalValues = _requireMap(
        entry.value,
        'extensions.prf.evalByCredential.${entry.key}',
      );
      _requireBase64UrlString(
        evalValues['first'],
        'extensions.prf.evalByCredential.${entry.key}.first',
      );
    }
  }
}
